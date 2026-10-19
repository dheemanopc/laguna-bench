# Work order 2 — follow-up: complete test coverage + full-suite verification

The source changes from order 1 look good — keep them. This order is mostly about tests that the
first order required but that are missing, plus the full-suite regression check (your report was cut
off before the baseline-vs-after comparison).

## A. Add the missing tests (in `tests/security/test_team_membership_authz.py`; keep existing ones)
Each must assert DB state, not just the error.

1. **Outsider takeover, add**: an outsider (tenant with NO relation to the team) calls
   `AddTeamMemberTool` with `member_id=<self>`, `role_key="owner"` → `code == -32603`,
   `data == {"missing_permission": "team.manage_members"}` (exact dict equality), and afterwards:
   no `team_role_assignments` row for (team, 'user', outsider) AND no `user_effective_team_access`
   row for (outsider, team). (Check the UEA table's column names in `teams/effective_access.py`.)
2. **Outsider takeover, assign**: outsider calls `AssignRoleTool(member_id=<owner>,
   new_role_key="viewer")` → refused as above; owner's role_key is still `owner`.
3. **Outsider takeover, remove**: outsider calls `RemoveTeamMemberTool(member_id=<owner>)` → refused;
   owner's `team_role_assignments` row and UEA row still present.
4. **Viewer denied**: a `viewer` of the team is refused for add, assign and remove of another member
   (parametrize or one test each), DB unchanged.
5. **Admin happy paths**: a user with role `admin` can add a member, assign a role (e.g. member →
   viewer, assert new role_key), and remove a member (row gone, UEA row gone).
6. **Creator end-to-end**: `CreateTeamTool` (as the creator — see how `tests/unit/test_team_api.py`
   calls it, but use UUID-suffixed emails) → then the creator adds a member with
   `AddTeamMemberTool`, changes that member's role with `AssignRoleTool`, and removes them with
   `RemoveTeamMemberTool` — all succeed with DB state asserted. Clean up the created team.
7. **Self-removal by non-admins**: a `viewer` and a `member` can each remove themselves (no
   permission) → row gone and UEA row gone.
8. **Removed member cannot re-add themselves (tool level)**: owner removes an `admin`; that removed
   user then calls `AddTeamMemberTool(member_id=<self>, role_key="owner")` → refused -32603, no row.
   Do this for both variants: (a) admin present only in `team_role_assignments`; (b) admin also has a
   legacy `team_members` 'admin' row for the team (insert one as in your `_has_role_via_legacy`).
9. **Email oracle**: in the existing `test_add_member_email_oracle`, also assert
   `real_exc.value.message == fake_exc.value.message`. Use a *real existing team* the caller is not in
   (in addition to / instead of a random UUID).

Also add to `tests/unit/test_team_role_permissions.py` (or the security file if it needs the DB) one
DB-backed test using `pg_pool`: the set of `role_key` from `roles_catalog WHERE plugin_id IS NULL`
equals the team-role keys of `ROLE_PERMISSIONS` (i.e. `ROLE_PERMISSIONS` keys minus system roles).
If that query returns extra/fewer keys than the 7, report what it returns rather than forcing it.

## B. Small description fix — `src/mem_mcp/mcp/tool_descriptions.py`
- add/assign: "before any DB lookup runs"/"before any DB access" is inaccurate (the check itself reads
  the DB). Say "before any other lookup (e.g. member_email resolution)".
- remove: drop the sentence about the legacy team_members row (implementation detail, not useful to
  an LLM caller). Keep: self-removal allowed; sole owner cannot remove themselves.

## C. Verification — report exact results
1. Run the new tests: `pytest -q -p no:cacheprovider tests/security/test_team_membership_authz.py tests/unit/test_team_role_permissions.py`.
2. Full regression: `git stash` your changes, run
   `pytest -q -p no:cacheprovider tests/unit tests/security tests/integration 2>&1 | tail -80`
   and record the failing test ids (baseline); `git stash pop`; run the same again. Report both
   failing-id lists and the difference. Every failure that appears only after the change must be
   explained (expected consequence of the gate vs. regression). In particular report the status of
   `tests/unit/test_team_api.py::test_add_team_member_team_cycle_rejects` before and after.
   Make sure `git stash pop` restores everything (including the new untracked files — use
   `git stash -u`).
3. `ruff check src tests`, `ruff format --check` on touched files, `mypy` — report.
4. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py` — report.
