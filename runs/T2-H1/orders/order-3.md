# Work order 3 — finish the tests and RUN the verification

The source and migration changes are accepted as they are. Do not change `src/` or the migration unless a test
exposes a real bug, and tell me if that happens. Last round you reported that you could not run shell
commands. In round 1 you could. Please run them now: `pytest`, `alembic`, `ruff`, `mypy` and `git` are all needed.
If a command is truly blocked, paste the exact error you get.

## Fixes to `tests/integration/test_references_access_regression.py`
1. Delete the superseded file `tests/integration/test_user_can_read_memory_regression_01a54.py`. It is your own
   file from round 1, so removing it is fine.
2. In both hard-delete tests, replace `pytest.raises(Exception)` with `pytest.raises(HardDeleteBlockedError)`
   and import it from `mem_mcp.teams.references`.
3. `test_resolve_own_memory_by_slug` calls `insert_slug_with_retry` with the wrong signature. The real one is
   `insert_slug_with_retry(conn, *, team_id, resource_type, clue, memory_id, title) -> str`. It returns the
   final slug, and `resource_type` must be `"decision"` or `"fact"`. Create the memory with type `'decision'`,
   use the returned slug in `resolve_reference_target`, and make the clue unique (uuid suffix).
4. Put back the write-path end-to-end test you dropped. Provision through `_provision_user_like_backfill`, make
   sure an `oauth_clients` row `plugin:<id>` exists as the repro does, and use `sdk_client_factory`:
   a. Backfill-provisioned user A writes M1 with the SDK, then writes M2 citing M1, and it succeeds. Then
      `memsys_refs_out` for M2 lists M1 as accessible, and `memsys_refs_in` for M1 lists M2.
   b. Backfill-provisioned user B cites A's M1 → `PluginValidationError` with code `memory_not_accessible`.
      Citing a random uuid4 also raises it. Assert that the two exceptions have equal `code` and equal
      `message`, and equal details/data attributes if the class has them.
5. In the refs_in/refs_out tool tests, remove the pointless `async with system_tx(pg_pool) as conn:` wrapper
   around the tool call. The tool opens its own transaction. Move the imports to the top of the module.
6. `TestCrossTenantUetaAccessStillWorks`: grant access with `mem_mcp.teams.assignments.assign_role(...)`, which
   is the real API path that populates UETA, as `tests/unit/test_references_helpers.py::_seed` does. Do not
   insert UETA rows by hand there. The hand-inserted UETA row is fine in the SQL-function test.
7. mypy runs in strict mode over `tests/`. Fully annotate the helpers and fixtures: `conn: Any`, `pool: Any`,
   `pg_pool: Any`, return types `dict[str, Any]` / `UUID`. Run `ruff format` on the file.
8. Cleanup must also delete `team_members` rows that the tests create. Today the teams cascade covers them, but
   make it explicit before the teams are deleted, and delete `oauth_clients` rows only if you created unique ones.

## Verification (paste exact commands with summary lines)
1. `alembic upgrade head`, then
   `psql "$MEM_MCP_DB_MAINT_DSN" -Atc "select pg_get_functiondef('user_can_read_memory(uuid,uuid)'::regprocedure)"`
   (or the asyncpg equivalent). Confirm there is no `deleted_at` filter. If the function in the DB still has it,
   run `alembic downgrade 0034_safe_current_tenant_id && alembic upgrade head`.
2. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_regression.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
3. Full suite **after**: `pytest -q -p no:cacheprovider tests`. Paste the summary line and every FAILED/ERROR id.
4. Full suite **baseline**: `git stash -u`, then `pytest -q -p no:cacheprovider tests`, paste the summary and the
   FAILED/ERROR ids, then `git stash pop` and show `git status --short`. List any failures that appear
   only in the "after" run. There should be none.
5. `ruff check src tests alembic`,
   `ruff format --check src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py tests/integration/test_references_access_regression.py alembic/versions/0035_2026_06_01_user_can_read_memory.py`,
   `mypy`. Show the result, plus whether any mypy errors are in the changed files. Pre-existing errors elsewhere
   are fine, but list the counts before and after.
