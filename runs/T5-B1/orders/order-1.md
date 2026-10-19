# Work order 1 — No lost updates in `memory_update` (revision tokens + DB row locking)

Read `CONVENTIONS.md` first and follow it. Relevant code: `src/mem_mcp/mcp/tools/update.py`,
`src/mem_mcp/mcp/tools/get.py` (`MemoryRecord`), `src/mem_mcp/mcp/tools/get_batch.py`,
`src/mem_mcp/mcp/tool_descriptions.py`, `src/mem_mcp/db/tenant_tx.py`, `alembic/versions/` (head is `0045_...`).

## Problem
Several agents edit the same memory concurrently via `memory_update`:
1. `tags_op="add"/"remove"` merges in Python against a row read earlier, so concurrent tag adds get lost.
2. Two concurrent content updates of a `decision`/`fact` (versioned) both create version N+1 → chain has two
   current rows. Same fork happens sequentially if a caller updates an id that is already superseded.
3. No optimistic concurrency: no way to say "only apply if the memory is still what I read".

Correctness must come from Postgres (row locks / conditional writes), NOT in-process locks (multiple workers).

## Required design (please implement this way)

### A. Migration `alembic/versions/0046_<date>_memory_revision.py` (down_revision = current head id — check 0045's `revision`)
- `ALTER TABLE memories ADD COLUMN revision uuid NOT NULL DEFAULT gen_random_uuid()` (existing rows each get a distinct value).
- A `BEFORE UPDATE` row trigger on `memories` that sets `NEW.revision := gen_random_uuid()` when
  `NEW.revision IS NOT DISTINCT FROM OLD.revision` AND any of
  `(content, type, tags, metadata, is_current, superseded_by, deleted_at)` IS DISTINCT FROM OLD.
  (So other writers — supersede/delete/undelete/write dedup — also bump it, but access-count/embedding
  backfill updates do NOT. That matters: `memory_get` fires an access-count bump right after reading; it must
  not invalidate the revision the caller just received.)
- Proper `downgrade()` (drop trigger, function, column). Check how earlier migrations handle grants/RLS
  for functions and mirror that if needed. Run `alembic upgrade head` on the test DB (env already configured).

### B. `MemoryRecord` (get.py)
- Add `revision: str` with a default so `MemoryRecord(...)` built from existing fields alone still works and
  reports a **non-empty string** revision, including in `model_dump()`. Suggested: field default `""` plus a
  `model_validator(mode="after")` that, when empty, derives a deterministic fallback (e.g.
  `f"{id}:{updated_at.isoformat()}"`). Accept UUID input from asyncpg (coerce to `str` via a `mode="before"` validator).
- Add `revision` to every SELECT that feeds `MemoryRecord` (memory_get main row + history CTE (both halves),
  get_batch both queries, and any other place `MemoryRecord(**row)` is built — grep for it). Real DB values
  must be returned as `str(uuid)`.

### C. `memory_update` (update.py)
- Input: `expected_revision: str | None = None`.
- Output `MemoryUpdateOutput`: add `revision: str` — but keep it constructible without it (existing tests build
  `MemoryUpdateOutput(id=..., version=..., is_new_version=..., tags=..., request_id=...)`), so give it a default
  (e.g. `""`; we always fill it from the DB in the tool).
- The initial lookup becomes a single `SELECT ... FOR UPDATE` that also selects `is_current, superseded_by, revision`.
  In READ COMMITTED, a waiter re-reads the latest committed row after the lock is released — so all decisions
  (tags merge, version number, is_current check, revision check) are made on the locked, fresh row.
  Keep it ONE `fetchrow` call: the existing mock unit tests (`tests/unit/test_tools_update.py`, must pass
  unchanged) use `fetchrow.side_effect = [lookup, insert_result]` and return dicts that LACK
  `is_current`/`superseded_by`/`revision`/sometimes `version`. So read those with `.get()` and sensible
  defaults (`is_current` defaults True). The in-place path's mocks make `fetchval` return a datetime and
  `fetchrow.return_value` return the lookup dict — keep the in-place write compatible with that (e.g. keep
  `fetchval(... RETURNING revision)`; if the returned value isn't a UUID/str, fall back gracefully — or
  structure it so the mocks still pass; the tests only assert id/is_new_version/version/tags).
- Order of checks after lock: not found (-32602, unchanged) → deleted (-32602, unchanged) →
  **not current** (`is_current` false) → conflict with `current_id` → **expected_revision mismatch** → conflict with `current_revision`.
- Conflict error: `JsonRpcError(-32000, "<message>", data={"code": "update_conflict", ...})` with
  - stale token: `data["current_revision"] = str(current revision)` (also include `current_id` = str(target id) is fine);
  - superseded target: `data["current_id"] = str(id of the is_current row of the chain)` — find it by walking
    `superseded_by` forward (recursive CTE, tenant-scoped) to the row with `is_current = true`; also include
    that row's `current_revision`. If no current row is found (e.g. chain head deleted) still raise update_conflict
    with what you have.
  Look at how other tools build -32000 errors (`undelete.py`, `search.py`) and match the style (message + data).
- In-place writes: `SET ..., revision = gen_random_uuid(), updated_at = now()` and `RETURNING revision` — every
  successful update (even a no-op one) gets a new revision.
- Versioned path: INSERT new row (gets its own default revision; `RETURNING id, version, revision`), then update
  the old row `SET is_current = false, superseded_by = $1 ... WHERE id = $2 AND tenant_id = $3 AND is_current`
  (the lock already guarantees it, the predicate is defence-in-depth). Output `revision` = new row's revision
  (must equal what `memory_get(new_id)` reports).
- Concurrency semantics that must hold: N concurrent `tags_op=add` each with a distinct tag → all tags present;
  N concurrent content updates of the same current decision → exactly one creates version 2, N−1 get
  update_conflict with `current_id` = new row id; N concurrent updates with the same valid `expected_revision`
  → exactly one succeeds; sequential update of an already-superseded id (decision v1 after v2 exists, or the
  note after note→decision promotion) → update_conflict with `current_id`.
- Watch for deadlocks: only lock the target row; the old-row UPDATE is on the same locked row.

### D. Tool description
Update `TOOL_DESCRIPTIONS["memory_update"]` in `tool_descriptions.py`: document `expected_revision`
(get it from `memory_get` → `memory.revision` or a previous `memory_update` output), that the output contains
`revision`, and the conflict contract (-32000, `data.code="update_conflict"`, `current_revision` / `current_id`;
re-read, merge, retry). Keep the existing description's style. Check whether any test asserts on description
length/format (grep tests for `TOOL_DESCRIPTIONS`) and comply.

### E. Schema docs
Run `python tools/dump_schemas.py` so `docs/schemas/` reflect the new fields (commit-equivalent: just leave files updated);
`python tools/dump_schemas.py --check` must pass afterwards.

### F. Don't change
- Plugin SDK `MemoryClient.update` signature (`src/mem_mcp/plugins/clients/memory.py`) — do not change it.
- Do not modify existing tests. Web handler (`web/handlers/memories.py`) already maps -32000 somewhere; just
  make sure its tests still pass (no need to add expected_revision passthrough there).

## Tests to add (new files)
1. `tests/unit/test_tools_update_revision.py` — mock-based: expected_revision mismatch → -32000/update_conflict
   with current_revision and nothing written (no INSERT/UPDATE calls); not-current target → update_conflict with
   current_id; `MemoryRecord` built without revision has non-empty str revision incl. `model_dump()`.
2. `tests/integration/test_update_concurrency.py` — REAL Postgres. Build the fixture like
   `tests/integration/test_mindmap_e2e.py` (tenant + team + primary identity with `default_team_id`), create
   memories with `MemoryWriteTool` + stub embedder. Create your **own** asyncpg pool with e.g. `max_size=12`
   (the default `pg_pool` fixture has only 4) — check how the existing pool fixture is created (db/pool.py,
   conftest) so codecs/init match. Close it at the end; `memory_get` fires a background access bump —
   let it drain (await pending tasks / small wait) before closing. Tests (each using `asyncio.gather` with
   ≥8 concurrent calls, `return_exceptions=True`):
   - concurrent `tags_op="add"` distinct tags → all present afterwards; same for `remove`;
   - concurrent content updates of a decision → exactly 1 success, rest update_conflict; exactly one
     `is_current` row in the chain; version 2 exists once;
   - concurrent updates with the same expected_revision → exactly 1 success;
   - sequential: update stale superseded id → conflict with correct `current_id`; note→decision promotion then
     update old note id → conflict;
   - revision: changes on every update (including tags-only and no-op), `memory_update` output revision ==
     `memory_get(...).memory.revision` (both paths; on versioned path for the new id); revision unchanged after
     `memory_get`'s access bump; history records carry revisions.
   To make the race actually happen, it's fine to put a tiny delay inside the stub embedder (`await asyncio.sleep(0.05)`).
   **Verify the tests fail without the fix**: temporarily stash/revert only update.py's locking (e.g. drop
   `FOR UPDATE` and the is_current check), run the concurrency tests, confirm they fail, restore. Report this.

## Verification to run and report (exact outputs/counts)
- `alembic upgrade head` (and `alembic downgrade -1 && alembic upgrade head` to prove downgrade works)
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_revision.py tests/integration/test_update_concurrency.py`
- run the concurrency test file 5 times in a row (flakiness check)
- full suite `pytest -q -p no:cacheprovider` — report failures; compare against baseline by running the full suite
  on a `git stash` of your changes first (or list which failures are pre-existing and why you believe so).
- `ruff check src tests`, `mypy`, `python tools/dump_schemas.py --check`
