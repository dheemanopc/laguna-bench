# Work order 3 — finish (previous session timed out; keep it short and focused)

Your previous session timed out before reporting. The repo state is fine (no stash pending). Do ONLY
the following, then report. Do not refactor or rewrite existing new tests beyond what's listed.

## 1. Tighten `TestOutsiderTakeover` in `tests/security/test_team_membership_authz.py`
The three tests must reproduce the actual reported attack (they currently use a third-party victim
with role 'member'). Change them to:
- **add**: outsider calls `AddTeamMemberTool(team_id=<team>, member_kind="user",
  member_id=<outsider self>, role_key="owner")` → `exc.value.code == -32603` and
  `exc.value.data == {"missing_permission": "team.manage_members"}` (exact dict equality); afterwards
  NO `team_role_assignments` row for (team, 'user', outsider) AND NO `user_effective_team_access` row
  for (outsider, team).
- **assign**: outsider calls `AssignRoleTool(member_id=<owner>, new_role_key="viewer")` → refused
  (same exact data); owner's role_key is still `owner`.
- **remove**: outsider calls `RemoveTeamMemberTool(member_id=<owner>)` → refused (same exact data);
  owner's `team_role_assignments` row AND owner's UEA row for the team still present.

## 2. Description fix — `src/mem_mcp/mcp/tool_descriptions.py`
In `memsys_assign_role`, remove "before any other lookup (e.g. member_email resolution)" — assign_role
has no member_email. Just say the caller lacking the permission receives -32603 with
data.missing_permission="team.manage_members" and nothing is changed.

## 3. Verification (report exact output lines)
a. `pytest -q -p no:cacheprovider tests/security/test_team_membership_authz.py tests/unit/test_team_role_permissions.py`
b. Baseline vs after, full suite:
   ```
   git stash -u
   pytest -q -p no:cacheprovider tests/unit tests/security tests/integration 2>&1 | grep -E "^(FAILED|ERROR)|passed|failed" > /tmp/before.txt
   git stash pop
   pytest -q -p no:cacheprovider tests/unit tests/security tests/integration 2>&1 | grep -E "^(FAILED|ERROR)|passed|failed" > /tmp/after.txt
   diff /tmp/before.txt /tmp/after.txt
   ```
   Confirm `git status` afterwards shows all 10 changed/new files and `git stash list` is empty.
   Paste the summary line of each run and the diff. Explain every FAILED/ERROR present only in
   "after" (expected consequence of the gate vs. regression). Note: tests share a DB that is not
   reset; if a test flips due to leftover data, re-run that single test to confirm.
c. `ruff check src tests`, `ruff format --check` on the 10 touched files, `mypy` — summary lines.
