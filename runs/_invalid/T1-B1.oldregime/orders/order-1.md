# Work order 1 — Admin user lookup over MCP (`memsys_admin_find_user` / `memsys_admin_get_user`)

Read `CONVENTIONS.md` first and follow it. No schema migration. Do not modify existing tests.

## Background
Operators holding the `system_admin` system role need to look up users cross-tenant from an MCP
client ("who is manasi, which teams is she in?"). Build two **read-only** tools on top of a reusable
`AdminTool` base so future admin tools (incl. mutating ones) cannot ship without a permission check.

## 1. Transport-agnostic service: new package `src/mem_mcp/admin/`
- `__init__.py`
- `errors.py`: `AdminError(Exception)` base, `NotFoundError(AdminError)`. No FastAPI / JsonRpcError imports anywhere in this package.
- `service.py` (module docstring explaining it is deliberately cross-tenant and does NOT authorize — callers gate first):
  - Pydantic (or frozen dataclass — Pydantic preferred so tools can embed it in output) models, e.g.
    `UserSummary` with `tenant_id: str`, `email`, `display_name` (nullable if the column is),
    `status`, `created_at: datetime`, and primary identity's `provider`, `workspace_domain`,
    `default_team_id: str | None`. `UserDetail(UserSummary)` adds `system_roles: list[str]` and
    `teams: list[UserTeam]` where `UserTeam` = `team_id: str`, `team_name: str`, `role_key: str`.
    Inspect the real schema in `alembic/versions/` (tables `tenants`, `tenant_identities` — find how the
    *primary* identity is marked, e.g. `is_primary` — `tenant_system_roles`, `teams`
    (`deleted_at`), `team_role_assignments` (`member_kind='user'`, `member_id`, `parent_team_id`,
    `role_id`, `status='active'`), `roles_catalog` (`role_key`)). Use a LEFT JOIN for the primary
    identity so a tenant without one still appears (identity fields then null; type them accordingly).
  - `_escape_like(raw: str) -> str`: backslash-escape `\` FIRST, then `%` and `_`.
  - `_clamp_limit(limit: int | None) -> int`: `None` → 20; clamp into 1..100 (never raise). Constants
    `DEFAULT_LIMIT = 20`, `MAX_LIMIT = 100`, `MIN_QUERY_LEN = 2` at module top.
  - `async def find_users(conn, *, query: str, limit: int | None = None) -> list[UserSummary]`:
    strip the query; `< 2` chars → `ValueError`. Case-insensitive substring match on email OR
    display name: `ILIKE $1 ESCAPE '\'` with pattern `'%' + _escape_like(q) + '%'` passed as a
    parameter (no string interpolation of values, ever). Order by `tenants.created_at DESC`
    (tie-break by id for determinism), `LIMIT $2` with the clamped limit.
  - `async def get_user(conn, *, tenant_id: UUID) -> UserDetail`: unknown tenant → `NotFoundError`.
    `system_roles` from `tenant_system_roles` (sorted). `teams` from `team_role_assignments` JOIN
    `roles_catalog` JOIN `teams`, `member_kind='user' AND member_id=$1 AND status='active' AND
    teams.deleted_at IS NULL` (order by team name). Do NOT use the legacy `team_members` table.
  - SQL must not cast the tenant GUC (it reads back as `''` after a rolled-back `tenant_tx` on a
    pooled connection) — the service should simply not depend on `app.current_tenant_id` at all.
- Tenant-scope linter (`tools/lint_tenant_scope.py`): the service queries per-tenant tables
  (`tenant_identities`, …) without a caller-tenant filter by design. Add `"src/mem_mcp/admin/"` (or
  the service file) to `EXEMPT_PREFIXES` with a justification comment in the same style as the
  existing entries (cross-tenant by design; callers gate on `system.manage_tenants` via AdminTool;
  runs under `system_tx`). `tests/unit/test_lint_tenant_scope.py` must stay green.

## 2. `src/mem_mcp/mcp/tools/_admin_base.py` — `AdminTool`
- Class with ClassVars `name`, `description`, `required_scope` (`"memory.read"` — comment why: no
  `memory.admin` scope exists in the Cognito resource server yet; the RBAC permission is the real
  control), `InputModel`, `OutputModel`, plus `required_permission: ClassVar[Permission]` and
  `audit_action: ClassVar[AuditAction]`.
- `__init_subclass__` guard: raise `TypeError` at class-definition time if a subclass defines
  `__call__` in its own `__dict__`, if a concrete subclass's `required_permission` is not a
  `system.*` `Permission`, or if `audit_action` does not start with `"admin."`. (Allow abstract
  intermediate subclasses that don't set the attrs only if you need them; otherwise enforce on
  every subclass.) Keep it simple and explicit.
- Abstract `async def run(self, conn: asyncpg.Connection, ctx: ToolContext, inp: BaseModel) -> BaseModel`.
- Final `async def __call__(self, ctx, inp)` flow:
  1. `async with system_tx(ctx.db_pool) as conn:` — `allowed = await has_permission(conn, ctx.tenant_id, self.required_permission)` (from `mem_mcp.auth.rbac`; no `team_id`).
  2. If denied: write the `denied` audit row on a **fresh, committed** `system_tx` (so it survives
     the failing call), then raise `JsonRpcError(-32603, "caller lacks required permission: <perm>",
     data={"missing_permission": "<perm value>"})`. The denial must be produced before any
     input-dependent DB work, so it is identical whether or not the target record exists. `run()`
     is never called.
  3. If allowed: inside `system_tx`, call `run()`; on success write the `success` audit row on the
     same conn (commits with it) and return. If `run()` raises (JsonRpcError or anything else), write
     an `error` audit row on a fresh `system_tx` (the failed tx is rolled back) with `error_code`
     (e.g. JsonRpcError code or exception class name), then re-raise unchanged.
  - Audit via `ctx.deps.audit.audit(conn, action=self.audit_action, result=..., tenant_id=ctx.tenant_id,
    identity_id=ctx.identity_id, client_id=ctx.client_id, request_id=ctx.request_id,
    details={"via": "mcp", "tool": self.name, "required_permission": self.required_permission.value, ...})`.
    Attribute to the **caller**, never the looked-up user (it's fine to put the target tenant id in
    `details`/`target_id` for get_user on success; do NOT include the raw query string beyond its
    length if you think it's sensitive — query length is enough, or include the query; your call,
    but never memory content). If `ctx.deps is None`, skip auditing (match how other tools handle it — check).
  - Exactly one audit row per call in every path.

## 3. Tools (one module each), registered in `src/mem_mcp/main.py`
- Add `"admin.find_user"` and `"admin.get_user"` to BOTH `AUDIT_ACTIONS` and the `AuditAction`
  Literal in `src/mem_mcp/audit/logger.py`.
- Descriptions in `src/mem_mcp/mcp/tool_descriptions.py` in house style ("Call when: / Do not call
  for: / Examples: … → …"), mentioning it requires the `system.manage_tenants` permission.
- `mcp/tools/admin_find_user.py`: `AdminFindUserInput(extra="forbid")`: `query: str` (Field
  min_length=2, max_length=255), `limit: int = Field(20, ge=1, le=100)`. `AdminFindUserOutput`:
  `users: list[UserSummary]`, `count: int`, `request_id: str`. `AdminFindUserTool(AdminTool)`, name
  `memsys_admin_find_user`, `required_permission = Permission.SYSTEM_MANAGE_TENANTS`,
  `audit_action = "admin.find_user"`. `ValueError` from service → `JsonRpcError(-32602, ...,
  data={"errors": [{"path": ["query"], "message": ...}]})`. (Note: whitespace-only padded queries like
  `"  a "` pass Pydantic but fail the service — that's the path this covers.)
- `mcp/tools/admin_get_user.py`: `AdminGetUserInput(extra="forbid")`: `tenant_id: UUID`.
  `AdminGetUserOutput`: `user: UserDetail`, `request_id: str`. name `memsys_admin_get_user`,
  `audit_action = "admin.get_user"`. `NotFoundError` → `JsonRpcError(-32602, "user not found",
  data={"errors": [{"path": ["tenant_id"], "message": "not found"}]})`.
- Register both in `main.py` with an `# admin` family comment, same as the other tool groups.
- Do NOT add any system.* permission to team roles in `auth/permissions.py`.

## 4. Tests (new files only; UUID-suffixed emails; tolerate shared DB)
- `tests/unit/test_admin_service_helpers.py` (DB-free): `_escape_like` (`\`, `%`, `_`, combined
  `\%` → `\\\%`, no double escaping), `_clamp_limit` (None→20, 0→1, -5→1, 50→50, 9999→100),
  short query `ValueError` (`""`, `" a "`) — can call `find_users` with a dummy conn since it should
  raise before any SQL; `AdminTool.__init_subclass__` guards (override `__call__` → TypeError,
  non-system permission → TypeError, bad audit_action → TypeError).
- `tests/unit/test_admin_service.py` (DB-backed via `pg_pool`, `system_tx`): seed tenants (+ primary
  identity, a team, an active team_role_assignment, a revoked/inactive assignment, an assignment on
  a soft-deleted team, a `tenant_system_roles` row) — reuse seeding helpers/patterns from existing
  tests (e.g. `tests/integration/test_mindmap_e2e.py`, enterprise team tests). Cover:
  case-insensitive match on email and on display name; newest first; `%%` returns none of your
  users (assert by asserting every result contains `%%` literally, i.e. result set is empty or
  only genuinely-matching rows); `_` matching literally; backslash literal; injection probe like
  `"' OR 1=1 --"` returns nothing and does not error; `limit=9999` → `len <= 100`; get_user returns
  system_roles, only active non-deleted-team assignments with role_key; unknown UUID →
  `NotFoundError`; **GUC regression**: acquire a pool conn, run a `tenant_tx` that raises to roll
  back, then run `find_users`/`get_user` via `system_tx` on the pool (use a `max_size=1` pool or
  same connection to force reuse) and assert it works.
- `tests/security/test_admin_tools_authz.py` (`pytestmark = pytest.mark.security`, DB-backed,
  `DbAuditLogger`): build `ToolContext` directly. Non-admin caller (plain tenant) AND a team
  **owner/admin** caller (team role on an active assignment): both tools raise JsonRpcError with
  `data == {"missing_permission": "system.manage_tenants"}`; `run()` not reached (monkeypatch/spy
  `run`); exactly one `audit_log` row for that `request_id` with `result='denied'`, action
  `admin.find_user` / `admin.get_user`, `tenant_id` = caller, details `via='mcp'`, `tool`,
  `required_permission`. Denial for get_user on an existing vs a random tenant_id → identical code
  and data. `system_admin` caller: find_user returns the seeded user case-insensitively with
  `count == len(users)`; get_user returns `system_roles` containing `system_admin`; exactly one
  `success` audit row attributed to the caller. 1-char / whitespace-padded query → -32602 (call via
  `ToolRegistry.dispatch` too, to show Pydantic validation also yields -32602). Unknown tenant →
  -32602, with an `error` audit row. Also exercise dispatch through `ToolRegistry` once to confirm
  output serialises (`model_dump(mode="json")`).
- Add a check that tools appear in the app's registry if `tests/unit/test_main.py` style makes this
  easy (new test file, don't edit existing).

## Verification — run and report EXACT results
1. Before changing anything: `pytest -q -p no:cacheprovider tests/unit tests/integration tests/security 2>&1 | tail -30` — record the baseline failing test ids.
2. After: same command; list any failures and confirm each was in the baseline.
3. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py` and your new test files (show output).
4. `ruff check src tests`, `ruff format --check` on your new/changed files, `mypy` — report output; new code must be clean.
Report: files changed, test commands + pass/fail counts, baseline vs after failures, any doubts
(e.g. schema surprises like how the primary identity is marked, RLS on `teams` under the test role).
