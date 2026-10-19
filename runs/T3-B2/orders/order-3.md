# Work order 3 — small polish + precise verification (no production-code changes)

1. In `tests/security/test_team_member_management_authz.py`: delete the no-op `_cleanup_team_env` stub,
   and delete `_create_tenant_with_identity` if it is unused. Remove the odd walrus
   `await tool(ctx := _ctx(...), inp)  # noqa: F841` in `test_non_admin_roles_denied_assign` — build `ctx`
   on its own line like the other tests. Do not change test semantics.
2. Run `pytest -q -p no:cacheprovider -rA tests/unit/test_team_api.py` and report the PASS/FAIL/ERROR
   status of every test in that file, one line each. For any that fail, state whether the reason is the new
   `team.manage_members` gate (e.g. `test_add_team_member_team_cycle_rejects`, whose caller has no role on
   team2) or a pre-existing fixture issue (e.g. duplicate `user1@example.com`), quoting the key error line.
3. Run the full `pytest -q -p no:cacheprovider tests/unit tests/security tests/integration -rfE` and give
   the list of FAILED/ERROR test ids. For the one extra ERROR you saw vs. baseline
   (`test_spec2_slug_lookup`), quote its error line and say whether it can possibly be related to this change.
   If you can, re-run that one test in isolation and report the result.
4. `ruff check src tests` and `mypy` — report results. Keep the final report short.
