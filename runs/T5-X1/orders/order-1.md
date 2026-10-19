# Work order 1 — No lost updates in `memory_update` (revision tokens + DB-serialized updates)

## Goal
Several agents edit the same memory concurrently via `memory_update` and we lose data:
1. Concurrent `tags_op="add"/"remove"` calls lose each other's tags (Python merge against a stale read).
2. Concurrent content updates to a versioned type (`decision`/`fact`) fork the chain (two `is_current` rows superseding the same parent). Same fork happens sequentially if a caller updates an id that is already superseded.
3. No optimistic concurrency: callers can't say "only apply if unchanged since I read it".

Correctness MUST come from the database (row locks / conditional writes), not in-process locks (multiple workers). **No Alembic migration** — use the design below.

## Design (follow this)

### A. Revision token (no schema change)
- Add to `src/mem_mcp/memory/versioning.py` a pure helper:
  `def compute_revision(memory_id: UUID | str, updated_at: datetime | None) -> str`
  returning an opaque non-empty string, e.g. first 24 hex chars of `sha256(f"{memory_id}:{micros}")`, where `micros` is the integer number of microseconds since the Unix epoch computed with **integer arithmetic** (`(dt - EPOCH) // timedelta(microseconds=1)`; treat a naive datetime as UTC; `None` → use `0` or similar so the result is still a non-empty string). Must be deterministic: the same (id, updated_at) from Python/asyncpg always yields the same string.
- `MemoryRecord` (`src/mem_mcp/mcp/tools/get.py`): add `revision: str = ""` plus a `model_validator(mode="after")` that, when `revision` is empty, sets it to `compute_revision(self.id, self.updated_at)`. So `MemoryRecord(**existing_fields)` still works and `model_dump()` includes a non-empty `revision`. This automatically flows to `memory_get` (memory + history), `memory_get_batch`, etc. Don't change their SQL.
- Because the revision is derived from `updated_at`, every `memory_update` write must make `updated_at` **strictly increase** for that row: in the in-place UPDATEs use
  `updated_at = GREATEST(clock_timestamp(), updated_at + interval '1 microsecond')` (instead of `now()`) and keep `RETURNING updated_at`; compute the output revision from the returned value. (Row is locked, see B, so this is race-free.)

### B. Serialization in `memory_update` (`src/mem_mcp/mcp/tools/update.py`)
- Initial lookup becomes `SELECT id, type, content, version, tags, metadata, deleted_at, is_current, updated_at FROM memories WHERE id = $1 AND tenant_id = $2 FOR UPDATE`. This row lock serializes all concurrent updates of the same row; under READ COMMITTED, a waiter re-reads the committed row after the lock is released. **Verify `tenant_tx` uses READ COMMITTED** (`src/mem_mcp/db/tenant_tx.py`); if it doesn't, tell me in your report before inventing something else.
- Order of checks after the lookup:
  1. not found → existing -32602 (unchanged)
  2. deleted → existing -32602 (unchanged)
  3. `is_current` is false → conflict (superseded). Use `target.get("is_current", True)`-style access: **the existing mock tests return dicts without `is_current`/`updated_at`/`version`**, and must keep passing unmodified.
  4. `inp.expected_revision is not None` and `!= compute_revision(target["id"], target.get("updated_at"))` → conflict (stale revision).
- Note: `is_current` is the source of truth for "current", not `superseded_by` (memory_delete can re-promote a prior version to `is_current=true` while its `superseded_by` still points at the deleted row).
- Tags merge (`_compute_tags`) then operates on the locked, fresh row → add/remove no longer lose updates. In-place content is last-writer-wins.
- Versioned path: since the old row is locked and checked `is_current`, of N concurrent content updates exactly one creates the new version; the rest wait, re-read `is_current=false` and get a conflict. Add `updated_at` to the INSERT's `RETURNING` and compute the output revision from the new row's `id` + `updated_at` (use `.get("updated_at")` — mock INSERT rows only have `id`, `version`). Output `revision` must equal what `memory_get(new_id)` reports.
- Keep the exact number/kind of `conn.fetchrow`/`fetchval`/`execute` calls on the success paths the same as today (mock tests use `side_effect` lists: versioned path = 2 fetchrow calls; in-place = fetchval returning a datetime). The extra query for the conflict path (finding current id) only runs on conflict.
- Optional defense in depth (do it if cheap): make the "mark old row superseded" UPDATE include `AND is_current = true`. Don't rely on its result count (mock `execute` returns a MagicMock).

### C. Input / output
- `MemoryUpdateInput.expected_revision: str | None = None`.
- `MemoryUpdateOutput.revision: str` (revision of the row that now holds the memory — new row on the versioned path).

### D. Conflict error contract
Raise `JsonRpcError(-32000, "<message>", data={...})` with `data["code"] == "update_conflict"`:
- Stale `expected_revision`: `data["current_revision"]` = current revision of the memory (string). Also include `data["current_id"] = str(target id)`.
- Superseded target: `data["current_id"]` = `str(id)` of the current version of the chain, found with a recursive CTE walking the chain in **both** directions (via `supersedes` and `superseded_by`) from the target, picking the row with `is_current = true AND deleted_at IS NULL` (highest version if several). Include `current_revision` for that row too if found. If none is found, `current_id` = None.
- Nothing must change on refusal (raise inside the tx before any write; the tx rolls back). Audit of a refusal is optional; if you audit, follow the existing audit pattern with `result` other than success — check CONVENTIONS.md for the error/audit model and follow it.
Check `src/mem_mcp/mcp/errors.py` and CONVENTIONS.md for how app errors (-32000) are expected to be shaped and follow it.

### E. Docs
Extend the `memory_update` entry in `src/mem_mcp/mcp/tool_descriptions.py`: describe `expected_revision` (obtained from `memory_get` → `memory.revision` or a previous `memory_update` result's `revision`), and the conflict contract (-32000, `data.code="update_conflict"`, `current_revision` / `current_id`; caller should re-read, merge, retry), and that updating a superseded id is refused. If there's a test asserting description length/format, keep it passing.

### F. Compatibility
- Do not change the plugin SDK's `MemoryClient.update` signature (`src/mem_mcp/plugins/clients/memory.py`). Check web handlers / plugin callers of memory_update still work (grep for `MemoryUpdateTool`, `MemoryUpdateInput`, `memory_update`); if any code builds `MemoryUpdateOutput` or does `MemoryRecord(...)` itself, make sure it still works.
- Do NOT modify existing tests.

## Tests to add
1. `tests/unit/test_update_revision.py` (mock-based / pure):
   - `compute_revision` deterministic, non-empty, changes when updated_at changes by 1µs, differs by id.
   - `MemoryRecord` built from only the old fields has non-empty string `revision`, present in `model_dump()`.
   - mock tool: stale `expected_revision` → -32000 / `update_conflict` / `current_revision`; `is_current=False` target → -32000 / `update_conflict` (mock the extra current-id query); matching `expected_revision` → success with `revision` in output.
2. `tests/integration/test_update_concurrency.py` — **real Postgres**, follow `tests/integration/test_mindmap_e2e.py` for tenant + team + primary identity with `default_team_id` and use `MemoryWriteTool` with a stub embedder to create memories. Create your own `asyncpg` pool with **max_size ≥ 12** (larger than the `pg_pool` fixture's 4), close it at the end (let memory_get's background access bump drain first, e.g. a short sleep / awaiting pending tasks). Tests:
   - 8–10 concurrent `tags_op="add"` each adding a distinct tag via `asyncio.gather` → final tags contain all of them. Same for `remove`.
   - N (≥5) concurrent content updates to the same current `decision` → exactly one succeeds (is_new_version, version 2), others raise -32000 `update_conflict` with `current_id` = the winner's id; DB has exactly one `is_current` row in the chain.
   - Sequential: update a decision (creates v2), then update the old v1 id → refused with `current_id == v2 id`; same for note→decision promotion then updating the old note id.
   - N concurrent updates with the same valid `expected_revision` → exactly one success; others conflict with `current_revision` equal to the revision `memory_get` reports afterwards.
   - Stale `expected_revision` sequential → refused, memory unchanged (content/tags/revision identical after).
   - `memory_update` output `revision` == `memory_get(...).memory.revision` (both in-place and versioned paths); two successive updates yield different revisions; a no-op update also changes the revision.
   - Use `return_exceptions=True` in gather and assert counts.
   **Prove these tests catch the bug**: temporarily stash the src changes (e.g. `git stash push src/`), run the concurrency tests and confirm they fail (the expected_revision ones will fail for missing field — the important ones are the tag-add and the decision-fork tests), then restore. Report what failed.

## Verification (report exact commands and pass/fail counts)
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_update_revision.py tests/integration/test_update_concurrency.py`
- Run the new concurrency test file 5 times in a row to check for flakiness.
- Full suite `pytest -q -p no:cacheprovider` **before** (via stash) and after your change; list failures in both and confirm no new failures.
- `ruff check src tests` and `mypy` — clean for files you touched.

## Report
Files changed, design notes (esp. tenant_tx isolation level confirmation), test results, anything uncertain.
