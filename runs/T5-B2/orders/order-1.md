# Work order 1 — No lost updates on `memory_update` (revision tokens + DB-serialized updates)

Read `CLAUDE.md` and `CONVENTIONS.md` first. Keep layering (`tenant_tx`, `JsonRpcError`). No in-process locks: correctness must come from Postgres (the server runs several workers).

## Problems to fix
1. Concurrent `tags_op="add"/"remove"` on the same memory lose edits (merge happens in Python on an unlocked earlier read).
2. Concurrent versioned content updates of the same `decision`/`fact` fork the chain (two current rows superseding the same parent). Same fork happens sequentially when a caller updates an id that is already superseded.
3. No optimistic concurrency: callers can't say "only apply if still what I read".

Files: `src/mem_mcp/mcp/tools/update.py`, `src/mem_mcp/mcp/tools/get.py` (`MemoryRecord`), `src/mem_mcp/memory/versioning.py`, `src/mem_mcp/mcp/tool_descriptions.py`.

## Design (follow this; no migration needed)

### Revision token
- Add to `src/mem_mcp/memory/versioning.py` a pure helper, e.g. `compute_revision(memory_id, updated_at) -> str`: an opaque, non-empty string derived from the row id and `updated_at` at **microsecond** precision, timezone-normalized (e.g. sha256 of `f"{id}:{epoch_microseconds_utc}"`, truncated to ~24 hex chars). It must tolerate `updated_at is None` / `memory_id is None` (still return a non-empty string) — mock-based unit tests feed partial rows.
- `MemoryRecord` (get.py): add `revision: str = ""` as a normal field, plus a `model_validator(mode="after")` that fills it with `compute_revision(self.id, self.updated_at)` when empty. So `MemoryRecord(**existing_fields)` still works and `model_dump()` contains a non-empty `revision`. memory_get, history records and get_batch then all expose it automatically.
- Every `memory_update` write must strictly advance `updated_at`, so two successive updates never yield the same revision: in both in-place UPDATE statements use `updated_at = GREATEST(clock_timestamp(), updated_at + interval '1 microsecond')` instead of `now()`, and RETURN the new `updated_at`.

### Locking / serialization in `MemoryUpdateTool.__call__`
- Initial lookup becomes `SELECT id, type, content, version, tags, metadata, deleted_at, is_current, superseded_by, updated_at FROM memories WHERE id = $1 AND tenant_id = $2 FOR UPDATE`. Under READ COMMITTED, waiting transactions re-read the latest committed row after the lock is released, so all subsequent checks/merges run against fresh data and updates serialize. Keep it as a single `conn.fetchrow` call.
- Order of checks after the lookup: not found → existing -32602; deleted → existing -32602; **not current** (`is_current` is False) → conflict (below); **stale `expected_revision`** → conflict; then proceed as today. All checks must happen before quota check / embedding.
- Access row fields that the existing mock tests don't provide via `.get()` with safe defaults: `is_current` missing → treat as current (True); `superseded_by`/`updated_at` missing → None. (The mocks in `tests/unit/test_tools_update.py` return plain dicts lacking these keys, and the versioned-path tests use `fetchrow.side_effect` with exactly TWO entries — initial lookup + INSERT — so do NOT add any extra `fetchrow` calls on the success paths. Extra queries only on conflict paths are fine. The in-place path's `fetchval` mock returns a datetime for `updated_at`.)
- Versioned path: INSERT ... `RETURNING id, version, updated_at`; mark the old row with `... SET is_current = false, superseded_by = $1 WHERE id = $2 AND tenant_id = $3 AND is_current = true` (defensive). Output revision = `compute_revision(new_row["id"], new_row.get("updated_at"))` — must equal what `memory_get(new_id)` reports.
- In-place path: output revision = `compute_revision(target["id"], <updated_at returned by the UPDATE>)`.

### Input / output
- `MemoryUpdateInput.expected_revision: str | None = None`.
- `MemoryUpdateOutput.revision: str`.

### Conflict error contract
Refused updates raise `JsonRpcError(-32000, <message>, data={...})` with `data["code"] == "update_conflict"` (check CONVENTIONS.md error model for the -32000 shape and follow it), plus:
- Superseded target: `data["current_id"]` = str id of the current version of the chain. Find it on the conflict path by following `superseded_by` forward (recursive CTE via `conn.fetchrow`/`fetchval`) to the row that is current and not deleted; if none, the last reachable row. Also include `data["current_revision"]` of that current row when found (helpful for retry).
- Stale `expected_revision`: `data["current_revision"]` = the locked row's current revision.
- Nothing must be written on refusal (raising inside `tenant_tx` rolls back). Not-found/deleted keep their -32602 errors.
- Put the conflict-detection logic in readable helpers (e.g. a small module-level function or private method); keep naming consistent with the file.

### Tool description
Update `TOOL_DESCRIPTIONS["memory_update"]` in `mcp/tool_descriptions.py`: document `expected_revision` (get it from `memory_get` → `memory.revision` or a previous `memory_update` result's `revision`), the `revision` output, that concurrent updates are serialized, and the conflict contract (-32000, `data.code="update_conflict"`, `current_revision` / `current_id`; re-read, merge, retry). Keep the existing text style. Check whether any test asserts on description text/length (grep tests for `tool_descriptions`/`TOOL_DESCRIPTIONS`) and don't break it.

Do NOT change the plugin SDK `MemoryClient.update` signature. Don't modify existing tests.

## Tests to add
1. Unit (new file, e.g. `tests/unit/test_tools_update_concurrency.py` or similar, mock-based): `MemoryRecord` built without revision has a non-empty string revision in `model_dump()`; `compute_revision` changes when updated_at changes by 1µs and is tz-normalized; stale `expected_revision` → -32000 update_conflict with current_revision and no UPDATE/INSERT executed; superseded target (`is_current=False`) → -32000 with `current_id`.
2. **Integration, real Postgres** (e.g. `tests/integration/test_update_concurrency.py`): follow `tests/integration/test_mindmap_e2e.py` for tenant + team + primary identity with `default_team_id`, `MemoryWriteTool` with a stub embedder. Create your **own asyncpg pool with max_size ≥ 10** (the default `pg_pool` fixture has only 4) — check how fixtures build pools/DSNs in `tests/conftest.py`/`tests/integration/conftest.py` and mirror it. `memory_get` fires a background access-count bump — let it drain before closing your pool. Tests (each must fail on the original code):
   - 8 concurrent `tags_op="add"` with distinct tags on one note → all 8 tags present afterwards (plus original tags).
   - Same for `tags_op="remove"` of 8 distinct tags → all removed.
   - 6 concurrent content updates of one current `decision` → exactly 1 success with version 2, 5 refused with -32000/`update_conflict` and `current_id` == the winner's id; DB has exactly one `is_current` row in the chain, exactly one row with `supersedes = original id`.
   - Sequential: update decision → v2; then update original id again → refused, `current_id` = v2 id, nothing written (row count unchanged). Same for a note→decision type promotion then updating the old note id.
   - 6 concurrent updates with the same valid `expected_revision` on a note → exactly one succeeds, others refused with `current_revision` equal to the winner's returned `revision`.
   - Revision semantics: `memory_get` revision == update output revision (in-place and versioned path — new id); two successive updates (even identical tag replace) yield different revisions; stale token refused and memory unchanged; omitting `expected_revision` still works.
   To make concurrency real, use `asyncio.gather` with each call going through `tenant_tx` on the larger pool (the tool opens its own tx per call). Optionally make the stub embedder `await asyncio.sleep(0.01)` to widen race windows.

## Verify & report
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py <your new tests>` — all pass.
- Temporarily confirm (by `git stash` of src changes only, or by reasoning if impractical) that the new integration tests fail on the original code; report how you checked.
- `pytest -q -p no:cacheprovider tests/unit tests/integration` before and after (stash to get baseline) — report the exact list of failures in both; no new failures allowed.
- `ruff check src tests` and `mypy` clean for touched files.
Report files changed, exact test commands and results.
