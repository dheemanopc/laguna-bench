# Work order 1 — Security fix: gate team member-management tools on `team.manage_members`

## Problem (security bug)
The three MCP tools `memsys_add_team_member`, `memsys_assign_role`, `memsys_remove_team_member`
(`src/mem_mcp/mcp/tools/add_team_member.py`, `assign_role.py`, `remove_team_member.py`) are only gated
by the OAuth scope `memory.write`, which every ordinary token has. They run under `system_tx` (RLS
bypassed). So any user who knows a team UUID can add themselves as `owner`, demote the real owner, and
remove members; a removed member can re-add themselves.

Also: `auth/permissions.py::ROLE_PERMISSIONS` only knows legacy team roles `admin`/`member`, so the
catalog roles `owner`, `viewer`, `vendor`, `customer`, `service-bot` resolve to *no* permissions in
`auth/rbac.py::has_permission` — i.e. a team's owner (as assigned by `memsys_create_team`) currently
has no `team.manage_members`.

Read `CONVENTIONS.md` first (layering, error model, opaque errors, tests).

## Required changes

### 1. Permission matrix — `src/mem_mcp/auth/permissions.py`
Make `ROLE_PERMISSIONS` cover exactly the system roles (unchanged) plus the 7 `roles_catalog` keys —
nothing invented:

| role_key | permissions |
|---|---|
| `owner`, `admin` | all team perms (`_TEAM_ADMIN_PERMS`: view, manage_members, manage_settings, delete, read, write) |
| `member` | view, read, write memory (`_TEAM_MEMBER_PERMS`) |
| `service-bot` | same as `member` |
| `viewer`, `vendor`, `customer` | `team.view` + `team.read_memory` only |

No team role gets any `system.*` permission. Update the module docstring/comments (they still say
team roles are only 'admin'/'member' in team_members) so they're accurate. Define a
`_TEAM_READONLY_PERMS` style constant rather than inline sets.

### 2. Shared transport-agnostic check (one helper, used by all three tools)
Create a domain-level helper (suggested: `src/mem_mcp/teams/authz.py`, or another place you judge
fits the layering better — it must NOT import FastAPI or `JsonRpcError`) e.g.:

```python
class TeamPermissionDeniedError(Exception):
    """Caller lacks a team-scoped permission. Carries .permission (str)."""

async def require_team_permission(conn, *, caller_id: UUID, team_id: UUID,
                                  permission: Permission) -> None: ...
```
It resolves via `mem_mcp.auth.rbac.has_permission(conn, caller_id, permission, team_id=team_id)`.
Note `mem_mcp.auth.rbac` imports FastAPI/web.sessions at module level; `_admin_base.py` imports it
lazily inside the function for that reason — follow the same pattern (lazy import + comment).

Then in the MCP layer add one shared mapping (e.g. a small helper in a `_`-prefixed module such as
`src/mem_mcp/mcp/tools/_team_authz.py`, or a function next to the helper usage) that converts
`TeamPermissionDeniedError` to:
```python
JsonRpcError(-32603, "caller lacks required permission: team.manage_members",
             data={"missing_permission": "team.manage_members"})  # raise ... from e / from None
```
(same shape as `_admin_base.py`). All three tools must use the same helper — no hand-rolled copies.

### 3. Tools
In each tool, inside the `system_tx`, run the permission check **first**, before any other DB access
or anything that could leak information (email lookup, role lookup, cycle checks, sole-owner check):

- **add_team_member**: check `team.manage_members` on `inp.team_id` BEFORE resolving `member_email`.
  A refused caller must get the identical error (code, message, data) whether or not the email belongs
  to a real account (no existence oracle). Input-shape validation (the member_id/member_email XOR
  checks that touch no DB) may stay before the gate.
- **assign_role**: check `team.manage_members` on `inp.team_id` before calling `assign_role`.
- **remove_team_member**: if `member_kind == "user"` and `member_id == ctx.tenant_id` (the caller
  removing themselves), skip the permission check — leaving a team never needs admin rights. The
  existing sole-owner guard (`SoleOwnerCannotSelfRemoveError`) must still apply. Otherwise check
  `team.manage_members`.
- A refused call must make NO change (no assignment row, no role change, no
  `user_effective_team_access` row). Raising inside the `system_tx` block rolls back, but the check
  runs before any write anyway.

### 4. Revocation must be real — legacy fallback
`rbac.get_team_role` falls back to the legacy `team_members` table when no `team_role_assignments`
row exists. Migration 0022 backfilled `team_role_assignments` from `team_members`, so legacy rows
still exist. After `remove_member` deletes a user's `team_role_assignments` row, a surviving legacy
`team_members` row (e.g. role 'admin') would still grant `team.manage_members`, letting a removed
admin re-add themselves. Fix this in the domain function `teams/assignments.py::remove_member`: for
`member_kind == 'user'`, also delete (or set `status` to a non-'active' value permitted by the table's
CHECK constraint — check migration 0015) the legacy `team_members` row for
(`team_id = parent_team_id`, `tenant_id = member_id`), in the same transaction. Add a comment explaining
why. Keep the SQL tenant-scoped so `tools/lint_tenant_scope.py` stays clean
(`tests/unit/test_lint_tenant_scope.py`).

### 5. Descriptions — `src/mem_mcp/mcp/tool_descriptions.py`
Update the three entries so they no longer say "placeholder"/"once Spec 5 ships". State: caller must
hold `team.manage_members` on the team (roles owner/admin); refusal returns -32603 with
`data.missing_permission = "team.manage_members"`; for remove: any user may remove themselves (except
the sole owner). Keep the house style.

## Tests to add (new file(s); do NOT modify existing tests)
E.g. `tests/security/test_team_membership_authz.py` (`pytestmark = pytest.mark.security`, plus the
skip-if-no-DSN pattern used elsewhere). Use the `pg_pool` fixture, `system_tx` for setup,
`mem_mcp.teams.assignments.assign_role` to build teams, and **UUID-suffixed emails** for every tenant
(see `tests/unit/test_team_api.py` for how tenants/identities/teams are inserted, but don't copy its
hard-coded emails). Clean up after yourself. Cover at least:

1. Outsider (no relation to team) → add_team_member(self as owner) refused: code -32603,
   `data == {"missing_permission": "team.manage_members"}`; no `team_role_assignments` row and no
   `user_effective_team_access` row for the outsider afterwards.
2. Outsider → assign_role(demote the owner to viewer) refused; owner's role unchanged.
3. Outsider → remove_team_member(owner) refused; owner row still present.
4. Email oracle: outsider add by `member_email` of a real account vs a nonexistent email → both
   refused with identical `code`, `message` and `data`.
5. A `member` and a `viewer` of the team cannot add/assign/remove others (refused).
6. Owner and admin can add, assign role, and remove another member (happy paths, DB state asserted).
7. End-to-end with `CreateTeamTool`: creator can then add a member via `AddTeamMemberTool`.
8. Self-removal: a `viewer`/`member` can remove themselves (row gone, UEA row gone); sole owner
   removing themselves still gets `sole_owner_cannot_self_remove`.
9. Revocation: after an admin is removed by the owner, that user can no longer re-add themselves
   (refused). Include a variant where the removed user also had a legacy `team_members` 'admin' row.
10. Unit test for the matrix (e.g. `tests/unit/test_team_role_permissions.py`): keys of
    `ROLE_PERMISSIONS` minus system roles == exactly the 7 catalog keys (also cross-check against
    `SELECT role_key FROM roles_catalog WHERE plugin_id IS NULL` if DB available); per-role sets match
    the table above; no team role has any `system.*` perm.

## Verification — run and report exact results
- Before changing anything, run `pytest -q -p no:cacheprovider tests/unit tests/security tests/integration`
  and save the list of failing test ids (baseline; some are pre-existing red).
- After your change, run the same command and report the diff of failures vs baseline (any new
  failure must be explained). Note: `tests/unit/test_team_api.py::test_add_team_member_team_cycle_rejects`
  has the caller add team1 into team2 where the caller has no role on team2 — if that test was passing
  at baseline and now fails with -32603, report it explicitly (do not edit it).
- `ruff check src tests`, `ruff format --check` on the files you touched, and `mypy` — report results.

Report: files changed, test commands + exact pass/fail counts, baseline vs after failure lists,
anything uncertain.
