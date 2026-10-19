# Work order 1 — Admin user lookup over MCP (`memsys_admin_find_user` / `memsys_admin_get_user`)

Read `CONVENTIONS.md` first; follow it (layering, error model, tool structure, audit, style).

## Goal
Operators holding the `system_admin` system role need to look up users from an MCP client, across
tenants ("who is manasi, and what teams is she in?"). Build two **read-only** tools, plus an
`AdminTool` base class so future admin tools can't ship without a permission check.

## 1. Service layer: new package `src/mem_mcp/admin/`
- `__init__.py` (short docstring).
- `errors.py`: `AdminError(Exception)` base, `NotFoundError(AdminError)`. No FastAPI or JsonRpcError imports
  anywhere in this package.
- `service.py` (module docstring: cross-tenant on purpose, callers MUST authorize first; the service does
  not authorize):
  - Pydantic (or frozen dataclass; Pydantic preferred so tool outputs can embed it) models
    `AdminUserSummary` with `tenant_id: str`, `email`, `display_name: str | None`, `status`, `created_at: datetime`,
    `provider: str | None`, `workspace_domain: str | None`, `default_team_id: str | None` — the last three
    come from the **primary** identity (`tenant_identities.is_primary`; LEFT JOIN so a tenant with no
    identity row still shows up with NULLs). `AdminUserTeam(team_id: str, team_name: str, role_key: str)`.
    `AdminUserDetail(AdminUserSummary)` adding `system_roles: list[str]` (sorted) and `teams: list[AdminUserTeam]`.
  - `_escape_like(raw: str) -> str`: backslash-escape `\` first, then `%` and `_`.
  - `_clamp_limit(limit: int | None) -> int`: `None` → 20 (constant `DEFAULT_LIMIT`), else clamp to
    `1..100` (`MAX_LIMIT`). Never raises.
  - `async def find_users(conn, *, query: str, limit: int | None = None) -> list[AdminUserSummary]`:
    strip the query; fewer than 2 chars → `ValueError`. Pattern built in Python as
    `"%" + _escape_like(q) + "%"`, passed as a `$n` parameter; SQL uses
    `t.email ILIKE $1 ESCAPE '\'  OR t.display_name ILIKE $1 ESCAPE '\'` (mind Python string escaping —
    the SQL Postgres sees must be `ESCAPE '\'`; verify with the backslash test below).
    `ORDER BY t.created_at DESC, t.id` (stable), `LIMIT $2` with the clamped limit. Parameterised only.
  - `async def get_user(conn, *, tenant_id: UUID) -> AdminUserDetail`: unknown tenant → `NotFoundError`.
    `system_roles` from `tenant_system_roles`. `teams` from the RBAC table:
    `team_role_assignments tra JOIN roles_catalog rc ON rc.id = tra.role_id JOIN teams tm ON tm.id = tra.parent_team_id`
    `WHERE tra.member_kind = 'user' AND tra.member_id = $1 AND tra.status = 'active' AND tm.deleted_at IS NULL`,
    ordered by team name, id. (Do NOT use the legacy `team_members` table.)
  - Must work on a connection that previously ran a rolled-back `tenant_tx` (custom GUC reads back as
    `''` not NULL after ROLLBACK). Don't read the GUC at all in this module.
- Linter: `tools/lint_tenant_scope.py` must stay clean. The admin service legitimately has no tenant filter;
  add `"src/mem_mcp/admin/"` to `EXEMPT_PREFIXES` with a comment explaining why (deliberately cross-tenant
  operator lookups, gated by the `AdminTool` RBAC check, run under `system_tx`). This is the designed
  configuration mechanism; don't contort SQL to fool the regex.

## 2. `src/mem_mcp/mcp/tools/_admin_base.py` — `AdminTool`
- Class implementing the `BaseTool` protocol shape, with ClassVars `name`, `description`, `required_scope`
  (`"memory.read"` — comment: no `memory.admin` scope exists in the Cognito resource server yet; the RBAC
  permission is the real control), `InputModel`, `OutputModel`, **plus** `required_permission: Permission`
  and `audit_action: AuditAction`.
- `__init_subclass__` enforcement (raise `TypeError` at class-definition time):
  - a subclass that defines `__call__` in its own `__dict__` → TypeError (subclasses must implement `run`).
    Also decorate base `__call__` with `typing.final`.
  - for concrete subclasses (those that define `name`): `required_permission` must be a `Permission` whose
    value starts with `"system."`; `audit_action` must start with `"admin."`. (Team roles never get `system.*`
    perms, so this keeps admin tools out of reach of team owners.)
- `async def run(self, conn, ctx, inp) -> BaseModel` — abstract (raise NotImplementedError).
- Base `__call__(self, ctx, inp)` flow:
  1. `async with system_tx(ctx.db_pool) as conn:` → `allowed = await has_permission(conn, ctx.tenant_id, self.required_permission)`
     (from `mem_mcp.auth.rbac`). If denied: write the `denied` audit row **in this same tx**, let the tx
     commit, then (outside the `async with`) raise
     `JsonRpcError(-32603, "caller lacks required permission: <perm>", data={"missing_permission": "<perm value>"})`.
     The check happens before looking at the input, so the denial is identical whether or not the target
     exists (no existence oracle). `run()` must never be reached on denial.
  2. If allowed: `async with system_tx(...) as conn:` → `out = await self.run(conn, ctx, inp)`; audit
     `success` in the same tx; return `out`.
  3. If `run()` raises (JsonRpcError or anything else): that tx rolled back, so write an `error` audit row on
     a **fresh** `system_tx` (with `error_code` = the JSON-RPC code as a string, or the exception type
     name), then re-raise unchanged.
  - Audit call: `ctx.deps.audit.audit(conn, action=self.audit_action, result=..., tenant_id=ctx.tenant_id,
    identity_id=ctx.identity_id, client_id=ctx.client_id, request_id=ctx.request_id, details={...})` —
    attributed to the **caller**, never the looked-up user. `details` always contains
    `"via": "mcp"`, `"tool": self.name`, `"required_permission": <perm value>`; subclasses may add
    non-sensitive extras via an overridable hook (e.g. `def audit_details(self, inp, out) -> dict`), e.g.
    `result_count`, `query_length` (don't store the raw query string), and for get_user pass the looked-up
    tenant as `target_id`/`target_kind="tenant"` (optional hook too). Keep it simple.
  - If `ctx.deps` is None: fail closed — still do the permission check, but audit cannot be skipped
    silently; use `DbAuditLogger()` as the fallback logger (comment why).
  - Exactly one audit row per call in every path.

## 3. Tools
- `src/mem_mcp/mcp/tools/admin_find_user.py`: `AdminFindUserTool`, name `memsys_admin_find_user`,
  `AdminFindUserInput(extra="forbid"; query: str = Field(min_length=2, max_length=255); limit: int = Field(20, ge=1, le=100))`,
  `AdminFindUserOutput(users: list[AdminUserSummary], count: int, request_id: str)`. Service `ValueError`
  (e.g. query `"  a "` passes length validation but strips to 1 char) → `JsonRpcError(-32602, ..., data={"errors":[{"path":"query","message":...}]})`.
  `audit_action = "admin.find_user"`.
- `src/mem_mcp/mcp/tools/admin_get_user.py`: `AdminGetUserTool`, name `memsys_admin_get_user`,
  `AdminGetUserInput(extra="forbid"; tenant_id: UUID)`, `AdminGetUserOutput(user: AdminUserDetail, request_id: str)`.
  `NotFoundError` → `JsonRpcError(-32602, "user not found", data={"errors":[{"path":"tenant_id","message":"not found"}]})`.
  `audit_action = "admin.get_user"`.
- Both: `required_permission = Permission.SYSTEM_MANAGE_TENANTS`, `required_scope = "memory.read"`.
- Add `"admin.find_user"`, `"admin.get_user"` to both `AUDIT_ACTIONS` and the `AuditAction` Literal in
  `src/mem_mcp/audit/logger.py` (new `# admin over MCP` group).
- Descriptions in `src/mem_mcp/mcp/tool_descriptions.py`, house style (what it does, requires system_admin,
  cross-tenant, read-only; "Call when: …", "Do not call for: …", "Examples: … → …").
- Register both in `src/mem_mcp/main.py` in the tool list, own family comment (`# admin (system_admin only)`).
- Do NOT touch `ROLE_PERMISSIONS` other than reading it; team roles must keep zero `system.*` perms.

## 4. Tests (new files only; do not modify existing tests)
Use `pg_pool`, UUID-suffixed emails/names, never assume empty tables. Look at existing tests to learn how
to create tenants, identities, teams, `team_role_assignments` and `tenant_system_roles` rows.
- `tests/unit/test_admin_service_helpers.py` (DB-free): `_escape_like` (incl. `\` not double-escaped, e.g.
  `a\%` → `a\\\%`), `_clamp_limit` (None→20, 0→1, -5→1, 9999→100, 50→50); `AdminTool` subclass defining
  `__call__` → TypeError; non-`system.*` permission → TypeError; `audit_action` not `admin.` → TypeError;
  every team role in `ROLE_PERMISSIONS` has no `system.*` permission.
- `tests/unit/test_admin_service_db.py` (DB-backed): case-insensitive match on email and on display_name;
  newest first; `%%` matches nothing of yours (create users then assert no result rows outside the ones
  that literally contain `%%` — simplest: assert none of your fixture users and count is not "everyone");
  literal `_` and `\` matching (create a user whose display_name contains `a_b` and one with `axb`; query
  `a_b` returns only the first; same idea with backslash); injection probe like `' OR 1=1 --` returns
  nothing / no error; `limit=9999` returns ≤100; 1-char and whitespace-padded 1-char query → ValueError;
  get_user: system_roles contains `system_admin` when granted, teams from RBAC table with role_key,
  excludes revoked assignment and soft-deleted team; unknown tenant → NotFoundError.
  **GUC regression**: on a single connection (`async with pg_pool.acquire() as conn:`), open a transaction,
  `set_config('app.current_tenant_id', <uuid>, true)`, roll it back (raise inside `conn.transaction()`), assert
  `current_setting('app.current_tenant_id', true)` is `''`, then call `find_users` / `get_user` inside a
  transaction on that same conn and assert they work.
- `tests/security/test_admin_tools_authz.py` (`pytestmark = pytest.mark.security`), using `DbAuditLogger`
  and a unique `request_id` per call so you can count audit rows `WHERE request_id = $1`:
  - non-admin caller: both tools raise JsonRpcError with `data == {"missing_permission": "system.manage_tenants"}`;
    `run()` never reached (monkeypatch `run` on the class to a function that records/fails); exactly one
    `audit_log` row with `result='denied'`, `action` = tool's audit action, `tenant_id` = caller,
    `details->>'via' = 'mcp'`, `details->>'required_permission' = 'system.manage_tenants'`.
  - get_user denial for an existing tenant_id vs a random UUID → identical code and data.
  - a team **owner** (active owner assignment in a team) is refused the same way.
  - `system_admin` caller: find_user returns the match case-insensitively with correct `count`; exactly one
    `success` row; get_user returns `system_roles` containing `system_admin`; unknown tenant →
    -32602 and exactly one `error` row; find_user `"  a "` → -32602.
  - registry dispatch: build a `ToolRegistry`, register both, dispatch via `registry.dispatch(ctx, name, params)`
    for one call to prove wiring + output serialises; and assert both names are registered in the app's tool
    list (check how other tests verify `main.py` registration, if any; otherwise import the tool list/registry
    construction from main if it's importable without side effects — skip this if not feasible and say so).

## Verification (report exact commands + pass/fail counts)
1. `pytest -q -p no:cacheprovider` on your new test files.
2. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py`
3. `ruff check src tests` and `mypy` — must be clean for your files.
4. Full suite `pytest -q -p no:cacheprovider` — before your change (`git stash` is fine, or compare against
   a baseline run first) and after; report the failing test IDs in both runs so we can confirm no new failures.

Report: files changed, test results, and anything uncertain.
