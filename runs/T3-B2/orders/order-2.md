# Work order 2 — cleanup + complete the test coverage

The production code from order 1 (`teams/authz.py`, `mcp/tools/_team_authz.py`, the three tools,
`permissions.py`, descriptions) is good — keep it. Fix the following.

## A. Remove artefacts (mandatory)
Delete these files completely; they must not be in the final diff:
- `_cleanup_db.py`, `_run_tests.py`, `_run_tests.sh`
- `tests/unit/test_db_cleanup.py` — it TRUNCATEs `teams`, `team_role_assignments`, `team_members`,
  `user_effective_team_access` as part of the normal suite. A test that wipes shared tables is not
  acceptable. Never truncate/bulk-delete data you didn't create; tests clean up only their own rows.

Also restore the `_ALL_TEAM` line in `src/mem_mcp/auth/permissions.py` (removing it is unrelated churn).
Run `ruff format` on the new/changed files only if the project uses ruff format (check pyproject) — do
not reformat untouched files.

## B. Missing security tests
Extend `tests/security/test_team_member_management_authz.py`. Mint emails with uuid suffixes; create
`tenant_identities` (primary) rows where an email lookup is needed; clean up every row you create
(including `user_effective_team_access` rows and any teams created via the create-team tool).
Required cases (each refusal asserts code == -32603 AND `data == {"missing_permission": "team.manage_members"}` exactly):
1. **Outsider takeover (the reported attack):** a tenant with NO relationship to the team calls add_team_member
   with `member_id=<self>`, `role_key="owner"` → refused; afterwards no `team_role_assignments` row for
   her on that team AND no `user_effective_team_access` row for her on that team (look at the table's
   columns in alembic/versions or `teams/effective_access.py` for the right column names).
2. Outsider `assign_role` demoting the owner to viewer → refused; owner's role still `owner`.
3. Outsider `remove_team_member` of the owner → refused; owner's row still present.
4. `viewer` (and `vendor` or `customer`) of the team refused for add and assign.
5. **Email oracle:** outsider calls add_team_member with `member_email` of an existing account, then with
   a nonexistent email → both refused; assert `code`, `message` and `data` are identical across the two.
   Also refused identically for a random nonexistent `team_id`.
6. **Removed member cannot re-add themselves:** owner removes a member (via the tool), then that ex-member
   calls add_team_member for themselves (role `member` and role `owner`) → refused, no row.
7. **Self-removal by a non-member:** a tenant with no role calls remove_team_member with
   `member_id=<self>` → refused with missing_permission (the existing `test_remove_self_denied_without_active_role`
   actually removes someone else — fix its name/docstring or add this proper case).
8. **Owner can manage:** owner adds a user (by id and by email), assigns a role, removes a member — all succeed.
9. **End-to-end with create_team:** call the `memsys_create_team` tool (find its tool class in
   `src/mem_mcp/mcp/tools/`) as a fresh tenant, then use that tenant to add a member, change that member's
   role, and remove them — all succeed. A second unrelated tenant is refused on the same team.
10. **Self-removal with a co-owner:** a team with two owners; one owner removes themselves → succeeds.

## C. Matrix test against the DB
In `tests/unit/test_team_role_permissions.py` (or the security file if it needs the DB), add a DB-backed test:
every `role_key` in `roles_catalog` where `plugin_id IS NULL` has an entry in `ROLE_PERMISSIONS`, and the
set of team-role keys in `ROLE_PERMISSIONS` (everything except `system_admin`/`system_support`) equals
that catalog set exactly. Also assert each role's exact permission set (equality, not just membership).
Also a `has_permission(..., team_id=...)` check that a `viewer` assignment resolves `team.read_memory`
True and `team.manage_members` False.

## D. Verification — report exact results (the last report was truncated; keep the final report concise)
1. `pytest -q -p no:cacheprovider tests/security/test_team_member_management_authz.py tests/unit/test_team_role_permissions.py tests/unit/test_team_api.py` — paste the summary line and any failures.
2. Full run `pytest -q -p no:cacheprovider tests/unit tests/security tests/integration`, and the same run
   against a `git stash` baseline (stash, run, `git stash pop` — make sure untracked new files are
   handled, e.g. `git stash -u`). Give the list of failing test ids for baseline and after, and
   explicitly list tests failing after but not at baseline, each with a one-line reason.
3. `ruff check src tests` and `mypy` results.
4. Confirm `git status` shows only intended files.
