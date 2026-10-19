# Work order 3 — fix test 4 in tests/integration/test_references_owner_access.py

Only touch `tests/integration/test_references_owner_access.py`, function
`test_assign_role_team_access_still_resolves`:

1. BUG: it inserts a team with `team_type = 'shared'`, which violates the CHECK constraint from migration 0022
   (`team_type IN ('personal','workspace','project','dept','customer','org','general')`). The test would fail
   with a CheckViolationError. Use `'project'` instead (and rename the variable/comments accordingly if you like).
2. The `finally: await _cleanup(... owner ..., member ..., shared_team)` can raise NameError (masking the real
   failure) if setup fails before those names are bound. Restructure like the other tests: do the setup in its own
   `async with pg_pool.acquire() / conn.transaction()` block BEFORE the `try:`, then put the assertions inside
   `try:` / `finally: _cleanup(...)`.
3. Remove the raw `team_role_assignments` insert for the member and the "before assign_role → denied" assertion.
   That assertion pins down UETA-staleness behaviour that isn't part of the contract. The test should just:
   provision owner + member (raw SQL, as now), create the project team owned by the owner, insert the owner's
   `visibility='team'` memory on that team, call `assign_role(conn, parent_team_id=project_team, member_kind="user",
   member_id=member tenant, role_key="member", assigned_by_user_id=owner tenant)`, then assert
   `resolve_reference_target(conn, target_uuid=m, caller_user_id=member tenant)` returns that memory and team.
   Optionally (nice to have) also assert via `sdk_client_factory(tenant_id=member tenant, plugin_id=_PLUGIN_ID)`
   that `sdk.write(..., references=[ReferenceInput(target_uuid=m, reference_kind="cites")])` succeeds. If you add the
   SDK assertion, `assign_role` must have committed first (do it in the setup transaction), and cleanup must still
   remove everything (memory_references rows from the member's memory are covered by `_cleanup` because the member's
   tenant is in the tenants list).

Also double-check the whole file once more for anything else that would fail at runtime against the schema
(CHECK constraints, NOT NULL columns, unique indexes, e.g. `slugs`, `teams`, `tenant_identities`), and for
ruff issues (unused imports/variables, line length 100). Fix anything you find, and list it in your report.

If Bash works this time, run:
`alembic upgrade head && pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_owner_access.py tests/integration/test_references_integration.py tests/integration/test_plugin_memory_client_it08.py tests/unit/test_references_helpers.py tests/unit/test_lint_tenant_scope.py`
then `pytest -q -p no:cacheprovider tests`, `ruff check src tests`, and `mypy`. Report the exact results. If Bash is
still denied, say so on the first line of your report.
