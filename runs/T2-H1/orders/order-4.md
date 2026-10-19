# Work order 4 — final cleanup (tests only) + hard evidence

Do not touch `src/` or the migration.

1. The file `tests/integration/test_user_can_read_memory_regression_01a54.py` STILL EXISTS. Your report said it
   was removed. Run `git rm -f tests/integration/test_user_can_read_memory_regression_01a54.py` (or `rm` it) and
   show `ls tests/integration | grep regression` afterwards.
2. Make `mypy tests/integration/test_references_access_regression.py` report **zero** errors. These errors come
   from the new file, not from pre-existing code:
   - Annotate every test method parameter (`pg_pool: Any`).
   - Build `ToolContext` / `ToolDeps` with the correct types. Read `src/mem_mcp/mcp/tools/_base.py` and
     `_deps.py`, and copy how an existing typed test builds a `ToolContext` (grep `tests/` for `ToolContext(`):
     a stub embedder object, the correct `scopes` type (e.g. frozenset/set if that is the declared type), etc.
   - Where tool output is typed `BaseModel`, narrow it with `assert isinstance(result, RefsInOutput)` /
     `RefsOutOutput` before you access attributes.
   - Give `_create_memory` a return type mypy accepts (e.g. wrap the fetchval result with `UUID(str(...))`, or
     annotate a local variable).
3. In `test_backfill_user_cites_own_memory_succeeds`, remove the useless `async with system_tx(pg_pool) as conn:`
   wrapper. Also assert that `result_out.refs[0].target_memory_id == str(m1)` and
   `result_in.refs[0].source_memory_id == str(m2)`, and that `inaccessible_count == 0` for both.
4. In `test_cross_tenant_write_same_error_opacity`, use `pytest.raises(PluginValidationError)` instead of
   try/except. Also assert `exc.value.code == "memory_not_accessible"` for both calls, on top of the existing
   equality checks. `plugin_id` / `owner_plugin` must be defined before the `try:` so that `finally` cannot
   hit a NameError. Do the same in the other e2e test.
5. Run `ruff format` and `ruff check` on the file.

## Evidence required (paste output verbatim or nearly verbatim)
a. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_regression.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py` → summary line.
b. `mypy tests/integration/test_references_access_regression.py src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py` → output. Note that mypy may also report errors in imported modules that predate this work. Report which of the errors are in our files.
c. Full suite after: `pytest -q -p no:cacheprovider tests -rfE 2>&1 | grep -E '^(FAILED|ERROR)' | sort > /tmp/claude-after.txt; tail -1` of the run, plus `wc -l`.
   Baseline: `git stash -u && pytest -q -p no:cacheprovider tests -rfE 2>&1 | grep -E '^(FAILED|ERROR)' | sort > /tmp/claude-before.txt; git stash pop`.
   Then `diff /tmp/claude-before.txt /tmp/claude-after.txt` and paste the full diff output. Any line that appears only in "after" must be explained. Also show `git status --short` after the stash pop.
