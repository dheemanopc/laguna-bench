# Work order 1 — No lost updates on `memory_update` (revision tokens + row locking)

## Problem
Several agents edit the same memory concurrently via `memory_update`
(`src/mem_mcp/mcp/tools/update.py`). Today:
1. `tags_op="add"/"remove"` merges in Python against a row read without a lock → concurrent tag adds are lost.
2. Two concurrent content updates of the same `decision`/`fact` both insert a new version superseding the
   same parent → two current rows (forked chain). Same fork happens sequentially if a caller updates an id
   that was already superseded.
3. No optimistic-concurrency option: a caller cannot say "only apply if unchanged since I read it".

Correctness must come from the database (row locks / conditional writes), NOT in-process locks (multi-worker).

## Design (follow this)

### 1. Revision token — derived from `(id, updated_at)`, no migration
- Add to `src/mem_mcp/memory/versioning.py` a pure function
  `memory_revision(memory_id: UUID, updated_at: datetime) -> str` returning an opaque non-empty string, e.g.
  `"r" + sha256(f"{memory_id}:{us}").hexdigest()[:24]` where `us` = integer microseconds since the Unix epoch
  (compute exactly with `(updated_at - EPOCH) // timedelta(microseconds=1)`; treat naive datetimes as UTC) so
  that tz representation never changes the result.
- `MemoryRecord` (`mcp/tools/get.py`) gains `revision: str = ""` plus a `model_validator(mode="after")` that
  fills it with `memory_revision(self.id, self.updated_at)` when empty. So `MemoryRecord(**existing_fields)`
  still works, and `model_dump()` contains a non-empty `revision`. This automatically covers history records,
  `get_batch.py`, etc. Make sure it serializes in tool output (check the JSON output path).
- Every write in `memory_update` must make `updated_at` strictly increase, so two successive updates never yield
  the same revision even inside the same microsecond/transaction timestamp: in BOTH in-place UPDATE statements use
  `updated_at = GREATEST(now(), updated_at + interval '1 microsecond')` and keep `RETURNING updated_at`.
- `access_tracking.bump_access` must NOT touch `updated_at` (verify; it currently doesn't) — a read must not change
  the revision.

### 2. Locking and refusal logic in `MemoryUpdateTool.__call__`
- The initial lookup (keep it as the FIRST and single `conn.fetchrow` before the write — the existing mock unit
  tests rely on the fetchrow call sequence: lookup, then (versioned path only) INSERT) becomes
  `SELECT id, type, content, version, tags, metadata, deleted_at, is_current, superseded_by, updated_at
   FROM memories WHERE id = $1 AND tenant_id = $2 FOR UPDATE`.
  The row lock serializes all concurrent updates of that row (READ COMMITTED re-reads the latest committed
  row after the wait), so the Python tag merge is now against fresh data and the version fork is impossible.
- Order of checks after the lookup:
  1. not found → existing -32602 (unchanged)
  2. deleted → existing -32602 (unchanged)
  3. not current (`is_current` false) → `JsonRpcError(-32000, "memory has been superseded", data={"code":
     "update_conflict", "current_id": "<str uuid of current version of the chain>", "errors": [...optional]})`.
     Resolve the current id by following `superseded_by` forward (recursive CTE, tenant-filtered,
     `WHERE tenant_id = $n` explicitly) to the row with `is_current = true` (non-deleted preferred; if none
     found, fall back to the last row reached). Use `conn.fetchval` (not fetchrow) for this helper.
  4. `inp.expected_revision is not None` and `!= memory_revision(target id, target updated_at)` →
     `JsonRpcError(-32000, "memory was modified since expected_revision", data={"code": "update_conflict",
     "current_revision": <current revision>, "current_id": "<target id str>"})`.
- Mock-compat: the unit-test mock lookup dicts lack `is_current`, `superseded_by`, `updated_at` (and sometimes
  `version`). Read them with `.get(...)` (asyncpg `Record` supports `.get`): missing `is_current` → treat as
  current; missing `updated_at` → if `expected_revision` was given, treat as mismatch is NOT required, just don't
  crash (simplest: only compute the current revision when `updated_at` is present).
- Versioned (new-version) path: the old row is locked, so after the INSERT also make the supersede UPDATE
  conditional: `... WHERE id = $2 AND tenant_id = $3 AND is_current = true` (defence in depth). The INSERT should
  `RETURNING id, version, updated_at`; output `revision = memory_revision(new_id, new_updated_at)` — must equal
  what `memory_get(new_id)` reports. In the mock tests the INSERT result lacks `updated_at`; use `.get` and fall
  back sensibly (e.g. `datetime.now(UTC)`) only when it's absent — real DB always returns it.
- In-place path: output `revision = memory_revision(target id, <updated_at returned by the UPDATE fetchval>)`
  (mock returns a datetime there).
- Preferably put the SQL helpers (lock+fetch, resolve current id) and an `UpdateConflictError` domain exception
  in `mem_mcp/memory/versioning.py` (or a new `memory/` module) per CONVENTIONS layering, mapping to
  `JsonRpcError` in the tool with `raise ... from e`. Keep the fetchrow/fetchval call sequence compatible with
  the existing mocks in `tests/unit/test_tools_update.py` (the tool's `tenant_tx` is monkeypatched there).
- Keep the embedding call where it is (inside the tx, under the lock) — fine.

### 3. Schema changes to models
- `MemoryUpdateInput`: `expected_revision: str | None = None`.
- `MemoryUpdateOutput`: `revision: str`.
- Do NOT change the plugin SDK `MemoryClient.update` signature (`src/mem_mcp/plugins/clients/memory.py`); check
  it and the web handler (`web/handlers/memories.py`) still work, and how they surface a -32000 error (should not
  crash; don't redesign them).

### 4. Description
Update `TOOL_DESCRIPTIONS["memory_update"]` in `src/mem_mcp/mcp/tool_descriptions.py` (house style) to document:
`expected_revision` (take `memory.revision` from `memory_get`; omit for last-writer-wins), output `revision`,
and the conflict contract: -32000 with `data.code="update_conflict"`; `data.current_revision` when the
revision is stale (re-read, merge, retry); `data.current_id` when the target was superseded (update the current
version instead). Concurrent updates are serialized; updating a superseded id is refused.

## Tests to add (do NOT modify existing tests)
New file e.g. `tests/integration/test_update_concurrency.py` against real Postgres (copy the fixture approach of
`tests/integration/test_mindmap_e2e.py`: tenant + team + primary identity with `default_team_id`, oauth client,
`MemoryWriteTool` with stub embedder, UUID-suffixed names). Create your OWN `asyncpg` pool with
`max_size >= 12` (same DSN/init as the `pg_pool` fixture in `tests/conftest.py`) so each concurrent call gets its
own connection; close it at the end (let `memory_get`'s background access bump drain first). Tests:
1. 10 concurrent `tags_op="add"` each adding a distinct tag to one `position`/`note` → final tags contain all 10.
   Also concurrent `remove` of distinct tags → all removed.
2. 8 concurrent content updates of one current `decision` → exactly one success (version 2), the rest
   -32000/`update_conflict` with `current_id` == the winner's id; DB has exactly one `is_current` row in the chain
   and exactly one row with `supersedes = v1`.
3. Sequential: update a superseded decision id → refused with `current_id` of v2; same for note→decision promotion
   then updating the old note id.
4. `expected_revision`: get → revision; update with it succeeds and returns a new revision equal to
   `memory_get(...).memory.revision`; second update with the old revision is refused with `current_revision` ==
   current one, and the memory is unchanged. Two successive no-op/same-content updates yield different revisions.
   Versioned path: output `revision` == `memory_get(new_id).memory.revision`.
5. N=8 concurrent updates with the same valid `expected_revision` (in-place note, and separately a decision content
   update) → exactly one succeeds, N−1 refused with `update_conflict`.
6. In-place concurrent content updates without token: all succeed, final content is one of them (last writer wins).
7. Unit test (no DB): `MemoryRecord` built from existing fields only has non-empty str `revision`, also in
   `model_dump()`; `memory_revision` is stable across tz representations of the same instant.
Confirm tests 1, 2 and 5 FAIL on the original code (e.g. `git stash` the src changes, run, restore) and report that.

## Verification (report exact results)
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py <your new tests>`
- `pytest -q -p no:cacheprovider tests/unit tests/integration` — compare failures against a baseline run of the
  untouched code (`git stash`) and list any difference; there must be no new failures.
- `ruff check src tests` and `mypy` clean for touched files.
- Report files changed, and anything uncertain.
