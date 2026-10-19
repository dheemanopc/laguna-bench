# Order 4 — Make the whole new suite green: fix wrong tests, xfail real bugs

Current state: unit files pass, but the integration files have failures, and there are ruff errors.
The deliverable is a suite where **every new test either passes or is a strict xfail for a
confirmed source bug**. Nothing may fail. Do not touch `src/`.

## Process (apply to each failing test in the 4 new files)
Run `pytest -q -p no:cacheprovider tests/integration/test_memory_list_behaviour.py tests/integration/test_plugin_notices_behaviour.py -rfE`
and classify every failure:
- **Test is wrong** (wrong expectation vs source/contract, or bad fixture/setup) → fix the test.
- **Source bug** (source violates the tool description / docstring contract) → keep the correct-behaviour
  assertion and mark `@pytest.mark.xfail(strict=True, reason="BUG: <exact cause>")`, and put the exact
  exception you observed in the reason or a comment.

## Known specifics
1. **memory_list default limit is 25**, not 20 (`MemoryListInput.limit` default = 25). The "default 20" in
   order 2 referred to `deliver_pending`. Fix `test_default_limit_is_20` / `test_default_limit_21_plus_returns_20`:
   insert 26 memories, call with `MemoryListInput()` → exactly 25 results + non-None `next_cursor`; and a
   separate test with exactly 25 → 25 results, `next_cursor is None`. Rename tests accordingly.
   Ensure there is a `deliver_pending(conn, tenant_id)` test (no `limit` kwarg) with 21 pending → exactly 20 returned,
   then a second call returns exactly the remaining 1.
2. **`type` is single-valued.** Replace `type=["note","fact"]` tests with a test that
   `MemoryListInput(type=["note","fact"])` raises `pydantic.ValidationError`.
3. **Cursor paging crash**: if passing `next_cursor` back raises (e.g. asyncpg `DataError` because the cursor
   timestamp is passed as a `str` to a timestamptz parameter), that's a real bug. Mark every pagination-walk and
   tie test that needs a second page `xfail(strict=True, reason="BUG: cursor timestamp passed to SQL as ISO str; asyncpg rejects it, so page 2 can never be fetched")`
   (adjust wording to what you observe). Use `raises=` only if the exception type is stable.
   Additionally add PASSING tests that pin the first page so cursor-building code is still covered:
   - With 7 memories (distinct created_at), `limit=3`, order desc: results == exactly the 3 newest in order, and
     `_decode_cursor(next_cursor) == (created_at_of_4th_newest.isoformat(), str(id_of_4th_newest))` — i.e. the
     (limit+1)th row, which is what the code does today. Do the same for order asc, and for `order_by="updated_at"`
     (where updated_at order differs from created_at order) to check the cursor uses updated_at. Get the
     timestamps from the DB (`SELECT created_at, updated_at ...`) so the isoformat matches exactly.
   - Separately, a strict-xfail test for the skip bug is only valid if paging otherwise worked; since page 2
     crashes, just state both issues in one xfail reason or the report. Do not write tests that pass only
     because of a crash.
4. **Invalid cursor at tool level**: for each malformed cursor, assert today's behaviour precisely:
   passing ones assert `exc.code == -32602`, `exc.message == "invalid cursor"` (check attribute names in
   `src/mem_mcp/mcp/errors.py`) and `exc.data["errors"][0]["path"] == "cursor"`. Ones that raise something else are
   strict xfails with reason naming the actual exception (KeyError / TypeError / asyncpg DataError, etc.).
5. **memory_versions / include_history**: find out why the history tests fail (look at the schema in
   `alembic/versions/` for triggers/constraints on `memories.is_current`/`version`, and how existing tests create
   non-current versions, e.g. via `MemorySupersedeTool` or a direct UPDATE). Make the setup correct; do not skip.
6. **ruff**: fix the unused variables and anything else; `ruff check tests` must be clean for the 4 files.
7. Remove/repair any test that "relies on pre-existing database issues" — no new test may depend on broken fixtures.

## Acceptance (report exact output)
- `git diff --stat HEAD -- src` empty.
- `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py tests/unit/test_memory_list_contract.py tests/unit/test_plugin_notices_contract.py tests/integration/test_memory_list_behaviour.py tests/integration/test_plugin_notices_behaviour.py`
  → 0 failed, 0 errors. Paste the final summary line.
- Same command 3 more times, plus once with `-n 4` if pytest-xdist is installed; paste summary lines.
- Full suite `pytest -q` summary line, and confirm the failing tests are all outside the 4 new files.
- `ruff check tests` result for the 4 files.
- A table of every strict xfail: test name → reason → actual exception/behaviour observed.
