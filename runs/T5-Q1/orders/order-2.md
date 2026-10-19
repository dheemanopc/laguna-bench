# Work order 2 — fix bugs in order-1 changes, add tests, RUN everything

You reported Bash was denied. Please retry: you need to run `alembic upgrade head`, `pytest`, `ruff`, `mypy`
in this order. If Bash is truly unavailable, say so explicitly at the top of your report — but still complete all
code + test-writing below.

## Bugs found in review of your diff (fix all)

1. **`resolve_current` in `memory/versioning.py`**:
   - `row["is_current"] = True` — asyncpg `Record` is immutable → TypeError at runtime. Return a plain dict
     (`dict(row)`) and do NOT overwrite `is_current`.
   - The anchor arm of the CTE lacks `AND tenant_id = $2` (tenant-scope linter + defence in depth). Add it.
   - Use proper types: `target_id: UUID, tenant_id: UUID`, return `dict[str, Any] | None`.
2. **Supersede check is wrong on the versioned path.** Because `resolve_current` forced `is_current=True`, a
   superseded decision is never refused; it then checks `expected_revision` against the *current* row's revision
   (wrong row) and still inserts a fork. Restructure: do ONE uniform check on the **locked target row itself**,
   right after the deleted check and before path selection / any embedding:
   ```python
   if target.get("is_current", True) is False or target.get("superseded_by") is not None:
       current = await resolve_current(conn, target["id"], ctx.tenant_id)
       data = {"code": "update_conflict", "current_id": str(current["id"] if current else target["superseded_by"])}
       if current and current.get("revision") is not None: data["current_revision"] = str(current["revision"])
       raise JsonRpcError(-32000, "memory has been superseded", data=data)
   ```
   Note `target.get("is_current", True)` — the mock rows in `tests/unit/test_tools_update.py` lack the key,
   so a missing key must mean "current". Your current in-place code `bool(target.get("is_current")) is False`
   treats missing as superseded and would break those unit tests.
   Then the expected_revision check compares against `str(target["revision"])` (the locked target row).
   If the target row has no `revision` key (mock), skip nothing special — just compare against `""`/str of what's there.
3. **`if not updated:`** — `conn.execute` returns a status string like `"UPDATE 0"`, which is truthy, so this guard
   never fires. Parse it: `if updated.split()[-1] == "0"` (be tolerant of mocks: only treat it as conflict when
   it's a str ending in `" 0"`). Raise the same superseded conflict (resolve current id via helper).
4. **Versioned output revision** is `str(new_row.get("id"))` — that's the id, not the revision. Use
   `RETURNING id, version, revision` on the INSERT and return `str(new_row["revision"])` (mock-tolerant: `.get`).
   Must equal `memory_get(new_id).memory.revision`.
5. **In-place output revision** returns the OLD revision (`target["revision"]`). Change both in-place UPDATEs to
   `RETURNING revision` and return that new value as str. The mock `fetchval` returns a datetime — that's fine,
   `str()` it; just make sure the unit tests pass unmodified.
6. Migration file: add trailing newline. Check `alembic heads` shows a single head `0046_memory_revision`
   (verify `0045_fix_turn_backfill` is indeed the revision id of the 0045 file).
7. `MemoryRecord.revision`: type should be `str` (not `str | None`) with the before-validator guaranteeing a
   value; the validator must not mutate the caller's dict in place — copy it (`data = dict(data)`) first.
   Also handle `data.get("revision")` being an empty string the same as None.
8. Tool description: use plain text / single backticks consistent with the rest of `tool_descriptions.py`
   (no RST double backticks). Keep it concise.

## Tests (not yet written — write them)
Write `tests/integration/test_memory_update_concurrency.py` and a small unit test for `MemoryRecord`
(e.g. `tests/unit/test_memory_record_revision.py`) exactly per the list in order-1 (items 1–10). Key points:
own asyncpg pool with max_size ≥ 12 created the same way `tests/conftest.py` creates `pg_pool` (same DSN env,
same init/codecs); fixture setup like `tests/integration/test_mindmap_e2e.py` with UUID-suffixed names; each
concurrent call its own `ToolContext` (unique request_id); `asyncio.gather(..., return_exceptions=True)`; assert
DB state directly (e.g. count of `is_current` rows where `id = v1 OR supersedes = v1`). To widen the race window
in the decision-fork test, you may use a stub embedder that `await asyncio.sleep(0.05)` in `embed()`.
Let `memory_get`'s background access bump drain before closing your pool (see `memory/access_tracking.py` for how).

Prove the tests catch the bugs: `git stash push src/mem_mcp/mcp/tools/update.py`, run tests 1 (tags add) and
3 (decision fork) → they must fail; `git stash pop`; → pass. Report the output.

## Verify and report (exact commands + results)
- `alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_memory_record_revision.py tests/integration/test_memory_update_concurrency.py`
  — run the concurrency file 3 times.
- Full suite on your branch, and a baseline: `git stash -u` → `pytest -q -p no:cacheprovider` → `git stash pop`
  (note the baseline DB will already have the revision column; that's fine). Report the failing test names for both
  and confirm no new failures.
- `ruff check src tests`, `ruff format --check` on changed/new files, `mypy`.
