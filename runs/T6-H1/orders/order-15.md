# Work order 15 — final verification (no new tests unless something fails)

Run each command and paste the output tails verbatim. Fix only issues in OUR new test files.

1. All related tests together (new + pre-existing for these modules):
   `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py tests/unit/test_search_preview_lenient.py tests/unit/test_memory_list_contract.py tests/unit/test_memory_list_sql_exact.py tests/unit/test_notice_pipeline_contract.py tests/unit/test_notice_exact.py tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py tests/integration/test_memory_list_filters_db.py tests/integration/test_plugin_notices_db.py -rxX 2>&1 | tail -30`
2. Same command again, with the file order reversed (pass the files in reverse order) — tail -3.
3. If `pytest -n` (xdist) works: same set with `-n 4` — tail -3. Otherwise say it's unavailable.
4. `ruff check tests/unit/test_memory_list_contract.py tests/unit/test_memory_list_sql_exact.py tests/unit/test_notice_pipeline_contract.py tests/unit/test_notice_exact.py tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py tests/integration/test_memory_list_filters_db.py tests/integration/test_plugin_notices_db.py`
   — fix any lint errors (unused imports/variables etc.; e.g. unused `m2`/`notice_id_1` variables — either use them
   in an assertion or drop them). Then `ruff format` those 8 files and re-run step 1 (tail -3).
   If ruff can't be run, paste the exact error.
5. Full suite: `pytest -q -p no:cacheprovider 2>&1 | tail -15`. List the failing test files; confirm none of them are our 8 files.
6. `git status --porcelain` — paste. Only the 8 new test files may appear (nothing under src/, alembic/, conftest, pyproject, or pre-existing tests).
