# T1 — Admin user lookup over MCP (`memsys_admin_find_user` / `memsys_admin_get_user`)

Category: pattern-conformant feature · Complexity: standard · Time box: 90–120 min

## Background

Operators (people holding the `system_admin` system role) currently have no way to
look up users from an MCP client. A typical request is "who is manasi, and what
teams is she in?" — the operator does not know the tenant_id, so the lookup is
cross-tenant by nature. Today the only admin surface is the web signup-review
routes (`src/mem_mcp/web/...`, gated with `require_permission`).

We want the first slice of "admin over MCP": two **read-only** tools, built so
that future admin tools (including mutating ones) cannot accidentally ship
without the permission check.

## What to build

1. A **transport-agnostic admin service layer** in a new package
   `mem_mcp.admin`:
   - `mem_mcp/admin/errors.py` — an error hierarchy with at least a base error
     and `NotFoundError`. No FastAPI / JSON-RPC types in this package.
   - `mem_mcp/admin/service.py` with:
     - `async def find_users(conn, *, query: str, limit: int | None = None) -> list[<summary model>]`
       — case-insensitive substring match on the user's email **or** display
       name across all tenants, newest signup first. Each result exposes at least
       `tenant_id` (as a string), `email`, `display_name`, `status`,
       `created_at`, and the primary identity's `provider`,
       `workspace_domain`, `default_team_id` (nullable).
       - A query shorter than 2 characters (after stripping whitespace) raises
         `ValueError`.
       - Operator input is a *literal* search string: LIKE wildcards (`%`, `_`)
         and backslashes in the query must match literally (a query of `%%`
         must not match every user). Expose this as a helper
         `_escape_like(raw: str) -> str` that backslash-escapes `\`, `%` and `_`
         (escaping `\` first so it is not double-escaped).
       - `limit` is clamped, never rejected: helper `_clamp_limit(limit: int | None) -> int`
         returns 20 for `None`, and clamps to the range 1..100.
       - Must be safe against SQL injection (parameterised queries only).
     - `async def get_user(conn, *, tenant_id: UUID) -> <detail model>` — the
       same fields as a summary plus `system_roles: list[str]` (from
       `tenant_system_roles`) and `teams` (team id, team name, the user's
       role_key) taken from the **RBAC assignment table**
       (`team_role_assignments` + `roles_catalog`), active assignments only,
       excluding soft-deleted teams. Unknown tenant → `NotFoundError`.
   - The service does not authorize; callers gate first.
2. An **`AdminTool` base class** in `mem_mcp/mcp/tools/_admin_base.py` for the
   `memsys_admin_*` family:
   - Class attributes on each concrete tool: `required_permission` (a
     `Permission`, must be a `system.*` permission) and `audit_action` (an
     audit action string starting with `admin.`), in addition to the usual
     `name` / `description` / `required_scope` / `InputModel` / `OutputModel`.
   - Subclasses implement `async def run(self, conn, ctx, inp) -> BaseModel`
     and **must not override `__call__`**. The base `__call__` enforces the
     RBAC permission (resolve it with the existing `has_permission` in
     `mem_mcp.auth.rbac`) *before* `run()` is reached. A denied caller must
     never reach `run()`.
   - Admin reads are cross-tenant, so they run under `system_tx` (no tenant GUC).
   - Denial → `JsonRpcError` whose `data` contains
     `{"missing_permission": "<permission value>"}` (same convention as the
     plugin-tool gate in `mcp/registry.py`). The denial must be **identical**
     (code and data) whether or not the requested record exists — no existence
     oracle.
   - **Every call is audited**, allowed or denied, via the tool context's audit
     logger, attributed to the **caller** (`tenant_id` / `identity_id` from the
     tool context, not the looked-up user): `action` = the tool's `audit_action`, `result` = `"success"` /
     `"denied"` (and `"error"` for other failures), `details` including
     `"via": "mcp"`, `"tool"` and `"required_permission"`. A denied call must
     leave exactly one audit row with `result="denied"` in `audit_log` — even
     though the call itself fails. A successful call leaves exactly one
     `admin.find_user` / `admin.get_user` row with `result="success"`.
   - Coarse OAuth scope stays `memory.read` for now (there is no `memory.admin`
     scope in the Cognito resource server yet); the RBAC permission is the real
     control.
3. Two tools, each in its own module, registered in `main.py` like the other tools,
   with descriptions in `mcp/tool_descriptions.py` (follow the existing
   "Call when / Do not call for / Examples" style), and the new audit actions
   added to the `AuditAction` literal:
   - `mem_mcp/mcp/tools/admin_find_user.py`: `AdminFindUserTool` (name
     `memsys_admin_find_user`), `AdminFindUserInput(query: str (2..255 chars), limit: int = 20 (1..100))`,
     output with `users: list[...]` and `count: int`. A `ValueError` from the
     service maps to JSON-RPC invalid params (-32602).
   - `mem_mcp/mcp/tools/admin_get_user.py`: `AdminGetUserTool` (name
     `memsys_admin_get_user`), `AdminGetUserInput(tenant_id: UUID)`, output
     `{user: <detail>}`. Unknown tenant → `JsonRpcError` code **-32602**.
   - Both require `Permission.SYSTEM_MANAGE_TENANTS`.
4. Team roles must never confer system permissions (the existing
   `ROLE_PERMISSIONS` matrix keeps `system.*` permissions out of team roles —
   keep it that way); a team owner must be refused.

## Constraints

- Follow existing patterns: tool modules under `mem_mcp/mcp/tools/`, Pydantic
  input/output models with `extra="forbid"` inputs, `JsonRpcError` error model
  (`mcp/errors.py`), `system_tx`/`tenant_tx` from `mem_mcp.db`, audit through
  `ctx.deps.audit`.
- `tools/lint_tenant_scope.py` (the tenant-scope linter, enforced by
  `tests/unit/test_lint_tenant_scope.py::...::test_real_codebase_is_clean`) must stay
  clean. The admin service legitimately has no tenant filter — handle that the
  way the linter is designed to be configured, with a comment saying why.
- No schema migration is needed or expected.
- Do not modify existing tests. Add your own tests (unit + DB-backed).
- The rest of the suite must not get new failures.

## Running tests

`MEM_MCP_TEST_DSN` points at a fresh, migrated Postgres for you. Run e.g.
`pytest -q -p no:cacheprovider tests/unit tests/integration tests/security`.
DB-backed tests use the `pg_pool` fixture from `tests/conftest.py`; create
tenants with UUID-suffixed emails so tests don't collide. Some tests are red
before you start (pre-existing fixture/data-collision issues); don't fix those.

## Acceptance (behavioural)

- Non-admin caller: both tools fail with `missing_permission =
  "system.manage_tenants"`, `run()` is never reached, one `denied` audit row is
  persisted with `via="mcp"` and `required_permission`.
- `system_admin` caller: find_user returns matches (case-insensitive) with a
  correct `count`; get_user returns `system_roles` containing `system_admin`.
- `%%`, injection probes and backslashes match nothing / literally; limit 9999 →
  at most 100 rows; 1-character query → `ValueError` (service) / -32602 (tool).
- The service works on a pooled connection that was previously used by a
  rolled-back `tenant_tx` (custom GUCs reset to `''`, not NULL, after ROLLBACK).
