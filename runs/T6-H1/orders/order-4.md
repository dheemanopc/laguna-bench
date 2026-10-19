# Work order 4 — SMALL, concrete: run the memory_list DB tests and add pagination tests

Your last report said the memory_list integration tests are "in progress", and
`tests/integration/test_memory_list_db.py` has had no new tests since order 1. Order 3 was not done.
This order is deliberately small. Do exactly these steps, in order. Same rules as before (new
test files only; no edits to src/alembic/conftest/pyproject/pre-existing tests).

## Step 1 — run and paste
Run exactly:
```
pytest -p no:cacheprovider tests/integration/test_memory_list_db.py -rxXs -v 2>&1 | tail -40
```
Paste that output **verbatim** at the top of your report. If any test is SKIPPED, ERRORS or
FAILS, fix the test file (not src) until all 14 run and pass. Typical causes: the
`pg_pool` fixture skipping (check `MEM_MCP_TEST_DSN` is set in your shell), wrong `memories`
columns in `_insert_memory`, or missing cleanup FKs.

## Step 2 — create `tests/integration/test_memory_list_pagination_db.py`
Reuse the helpers by importing them from `tests.integration.test_memory_list_db`
(`_setup_tenant_and_team`, `_cleanup_tenant`, `_build_ctx`, `_insert_memory`) — or copy them.
Use `pytestmark = pytest.mark.asyncio`. Base time `base = datetime(2026, 1, 1, tzinfo=UTC)`.

Write these tests (each with its own tenant via setup/cleanup in try/finally):

1. `test_first_page_and_cursor_points_at_overflow_row` — insert m0..m4 with
   `created_at = base + timedelta(minutes=i)`. Call `MemoryListInput(limit=2)`.
   Assert `[r.id for r in out.results] == [m4, m3]` and
   `_decode_cursor(out.next_cursor) == ((base + timedelta(minutes=2)).isoformat(), str(m2))`.
   (Note: asyncpg returns created_at as UTC-aware datetimes; compare isoformat of the value you
   read back from the DB if the tz rendering differs — but make the assertion exact.)
2. `test_full_walk_desc` — same data; loop:
   ```
   ids, cursor = [], None
   for _ in range(10):
       out = await tool(ctx, MemoryListInput(limit=2, cursor=cursor))
       ids += [r.id for r in out.results]
       cursor = out.next_cursor
       if cursor is None:
           break
   assert ids == [m4, m3, m2, m1, m0]
   ```
3. `test_full_walk_asc` — same with `order="asc"`, expected `[m0, m1, m2, m3, m4]`.
4. `test_full_walk_updated_at` — created_at ascending by i, `updated_at = base + timedelta(hours=k)`
   with k = [3, 0, 4, 1, 2] for m0..m4 → `order_by="updated_at"` desc expected `[m2, m0, m4, m3, m1]`.
5. `test_full_walk_ties_desc` — three memories with identical `created_at = base`, `limit=1`;
   expected: collected ids is a permutation of all three with no duplicates and length 3
   (`sorted(ids) == sorted([a, b, c])` and `len(ids) == 3`).

**Run them.** For each of 2–5 that fails, look at the actual failure:
- if it raises, add `@pytest.mark.xfail(strict=True, raises=<ExactExceptionClass>, reason="BUG: <observed message, shortened>")`
- if it returns wrong ids, add `@pytest.mark.xfail(strict=True, reason="BUG: <which ids were missing/duplicated>")`.
Test 1 must PASS (it pins current behaviour). Don't change the expected values to match buggy
output.

## Step 3 — run and paste
```
pytest -p no:cacheprovider tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py -rxXs -v 2>&1 | tail -40
```
Paste verbatim. Then for each xfail, paste the *actual* exception/assertion text you observed
when it was not marked (one line each). Also run `ruff check` and `ruff format --check` on the new file.

Keep the report short: the two pasted outputs, the observed failure text per xfail, ruff results.
