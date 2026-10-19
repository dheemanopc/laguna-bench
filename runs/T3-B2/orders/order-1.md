# Work order 1 — Gate team member management on `team.manage_members` (security fix)

## Problem
`memsys_add_team_member`, `memsys_assign_role`, `memsys_remove_team_member`
(`src/mem_mcp/mcp/tools/{add_team_member,assign_role,remove_team_member}.py`) are gated only by the
OAuth scope `memory.write`, which every token has. Anyone who knows a team UUID can add themselves as
`owner`, demote the real owner, or remove members. The tools run under `system_tx` (RLS bypassed), so an
explicit permission check is the only control.

## Required changes

### 1. Permission matrix — `src/mem_mcp/auth/permissions.py`
`ROLE_PERMISSIONS` only knows team roles `admin`/`member`; every other `roles_catalog` key resolves to no
permissions. Make the team-role entries cover exactly the catalog roles (keep the two system roles as is,
invent nothing else):

| role_key | permissions |
|---|---|
| `owner`, `admin` | all six `team.*` perms (`_TEAM_ADMIN_PERMS`) |
| `member`, `service-bot` | `team.view`, `team.read_memory`, `team.write_memory` |
| `viewer`, `vendor`, `customer` | `team.view`, `team.read_memory` only |

No team role may hold any `system.*` permission. Add a read-only perm set constant alongside the existing
ones; update the comments that say team roles are only 'admin'/'member'. Check `src/mem_mcp/auth/plugin_perms.py`
(it references ROLE_PERMISSIONS) still behaves sensibly.

### 2. Shared transport-agnostic check
Create one helper used by all three tools (no hand-rolled copies), e.g. `src/mem_mcp/teams/authz.py`
(pick the location that best fits CONVENTIONS.md layering):

- Exception class, e.g. `TeamPermissionDeniedError(Exception)` carrying `.permission` (the string
  `"team.manage_members"`). It must not know about JSON-RPC or HTTP (same layering as `mem_mcp.admin.errors`).
- `async def require_team_permission(conn, caller_id, team_id, permission) -> None` which calls
  `mem_mcp.auth.rbac.has_permission(conn, caller_id, permission, team_id=team_id)` and raises the exception
  if false. Note `_admin_base.py` imports `has_permission` lazily because `rbac` pulls in FastAPI — follow
  the same lazy-import pattern (or whatever avoids an import cycle).
- Map it in the MCP layer to exactly:
  `JsonRpcError(-32603, "caller lacks required permission: team.manage_members", data={"missing_permission": "team.manage_members"})`
  (matches `_admin_base.py` and CONVENTIONS.md). Put this mapping in a single place shared by the three
  tools (e.g. a small helper in `mcp/tools/` or a shared function), not three copies of the message.

### 3. Apply in the tools — the check runs FIRST inside the `system_tx`, before any DB lookup/write
- **add_team_member**: keep the cheap input-validation (XOR) checks before, but the permission check must
  run before the `member_email` → tenant lookup. A refused caller must get the identical error (code,
  message, data) whether the email exists or not. Also identical whether the team exists or not.
- **assign_role**: check before `assign_role(...)`.
- **remove_team_member**: self-removal exception — if `member_kind == "user"` and
  `member_id == ctx.tenant_id` AND the caller currently has an active role in the team
  (`get_team_role(...) is not None`), skip the `team.manage_members` check (leaving never needs admin rights).
  Otherwise require the permission. The existing sole-owner guard (`SoleOwnerCannotSelfRemoveError`) must
  still apply.
- A refused call must make no change at all (no assignment row, no role change, no
  `user_effective_team_access` row).
- `memsys_create_team` must keep working: the creator gets `owner`, and an owner must be able to
  add/assign/remove. Verify `owner` resolves via `get_team_role` (it reads `team_role_assignments`).

### 4. Tool descriptions — `src/mem_mcp/mcp/tool_descriptions.py`
Update the three entries: remove the "placeholder / enforced once Spec 5 ships" language; state that the
caller must hold `team.manage_members` on the team (owner/admin), that refusal returns -32603 with
`data.missing_permission`, and for remove that a user may always remove themselves (sole-owner guard
still applies). If any test asserts on description content/length, keep it passing.

## Tests (add new files; do NOT modify existing tests)
Add e.g. `tests/security/test_team_member_management_authz.py` (and a unit test for the matrix, e.g.
`tests/unit/test_team_role_permissions.py`). Use the `pg_pool` fixture from `tests/conftest.py`,
`system_tx` for setup, `mem_mcp.teams.assignments.assign_role` to build teams, UUID-suffixed emails, and
clean up after yourselves. Look at `tests/unit/test_team_api.py` for how to build a `ToolContext` and
tenants/identities/teams. Cover at least:
1. Outsider (Mallory) cannot add herself as owner → JsonRpcError -32603, data == {"missing_permission": "team.manage_members"}; no `team_role_assignments` row and no `user_effective_team_access` row for her.
2. Outsider cannot assign_role (demote owner) → refused, owner's role unchanged.
3. Outsider cannot remove the owner → refused, row still present.
4. A `member` / `viewer` of the team is refused for all three as well.
5. Email oracle: refused caller with `member_email` of an existing account vs a nonexistent email → identical code, message and data.
6. Removed member cannot re-add themselves.
7. Self-removal: a `member` can remove themselves; a sole owner removing themselves still gets `sole_owner_cannot_self_remove`; a non-member "removing themselves" gets the normal refusal.
8. Owner (and admin) can add / assign / remove. Also an end-to-end case using `memsys_create_team` (the create-team tool) then the creator adding a member.
9. Matrix: each of the 7 catalog roles has exactly the table's permissions; no team role has any `system.*` perm; every `roles_catalog.role_key` in the DB has a `ROLE_PERMISSIONS` entry.

## Known expected impact on existing tests
`tests/unit/test_team_api.py::test_add_team_member_team_cycle_rejects` has tenant1 add a team to team2
where tenant1 has no role on team2. With the gate it will now be refused with missing_permission before
the cycle check — that is the intended security behaviour. Do NOT modify that test; just report it. Any
other existing test that changes from pass→fail must be reported with the reason; first check whether
your change is wrong.

## Verification — report exact results
1. On a clean checkout (`git stash` your changes, or before you start), run
   `pytest -q -p no:cacheprovider tests/unit tests/security tests/integration` and record the failing test ids (baseline).
2. After changes, run the same command; list any test failing now that did not fail at baseline.
3. `ruff check src tests` and `mypy` — clean for your files.
Report: files changed, baseline vs after failures (test ids), lint/mypy output.
