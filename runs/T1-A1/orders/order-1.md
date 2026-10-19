# Work order 1 — Admin user lookup over MCP (`memsys_admin_find_user` / `memsys_admin_get_user`)

Read `CLAUDE.md` and `CONVENTIONS.md` first; new code must follow them. No schema migration. Do not modify
existing tests (you may only ADD test files). Keep changes focused.

## Goal
Operators holding the `system_admin` system role need to look up users cross-tenant from an MCP client
("who is manasi, which teams is she in?"). Build two **read-only** MCP tools on top of a transport-agnostic
service layer, plus an `AdminTool` base class so future admin tools cannot ship without the permission check.

## 1. Service layer — new package `src/mem_mcp/admin/`
- `__init__.py`, `errors.py`, `service.py`. **No FastAPI / JsonRpcError imports in this package.**
- `errors.py`: `AdminError(Exception)` base, `NotFoundError(AdminError)`.
- `service.py` (module docstring explains: cross-tenant by design, callers must authorize first, runs under
  `system_tx`):
  - Pydantic models, e.g. `AdminUserSummary` with at least: `tenant_id: str`, `email`, `display_name`
    (nullable), `status`, `created_at: datetime`, and the **primary** identity's `provider`,
    `workspace_domain` (nullable), `default_team_id: str | None`. Use LEFT JOIN on
    `tenant_identities ti ON ti.tenant_id = t.id AND ti.is_primary` so tenants without a primary identity
    still appear (identity fields nullable then).
  - `AdminUserDetail(AdminUserSummary)` + `system_roles: list[str]` (from `tenant_system_roles`, sorted) +
    `teams: list[AdminUserTeam]` where `AdminUserTeam` = `team_id: str`, `team_name: str`, `role_key: str`.
    Teams come from **`team_role_assignments` JOIN `roles_catalog`** (`member_kind='user'`,
    `member_id = tenant_id`, `status='active'`) JOIN `teams` with `deleted_at IS NULL`. Do NOT use the
    legacy `team_members` table. Deterministic ordering (e.g. by team name, id).
  - `_escape_like(raw: str) -> str`: backslash-escape `\` first, then `%` and `_`.
  - `_clamp_limit(limit: int | None) -> int`: `None` → 20; clamp into 1..100 (never raise). Constants
    `DEFAULT_LIMIT = 20`, `MAX_LIMIT = 100` at module top.
  - `async def find_users(conn, *, query: str, limit: int | None = None) -> list[AdminUserSummary]`:
    strip query; `len < 2` → `ValueError`. Case-insensitive substring match on `t.email` OR
    `t.display_name` using `ILIKE '%' || $1 || '%' ESCAPE '\'` with `$1 = _escape_like(q)` (parameterised
    only; no f-string/format SQL). Order `t.created_at DESC, t.id`. `LIMIT $2` with the clamped value.
  - `async def get_user(conn, *, tenant_id: UUID) -> AdminUserDetail`; unknown → `NotFoundError`.
  - Must work on a pooled connection previously used by a rolled-back `tenant_tx` (GUC reads back `''`).
    Don't read `app.current_tenant_id` at all in this module. Note the tables touched may have RLS; the
    test DSN role's behaviour under `system_tx` is what the existing `has_permission` / web admin code
    relies on — verify with real DB tests.
- **Tenant-scope linter** (`tools/lint_tenant_scope.py`): add `"src/mem_mcp/admin/service.py"` to
  `EXEMPT_PREFIXES` with a justification comment (cross-tenant operator lookup; callers gate with
  `system.manage_tenants` via `AdminTool`; runs under `system_tx`), in the same style as existing entries.
  `tests/unit/test_lint_tenant_scope.py::...::test_real_codebase_is_clean` must pass.

## 2. `AdminTool` base — `src/mem_mcp/mcp/tools/_admin_base.py`
- Abstract base class (it does satisfy the `BaseTool` protocol). ClassVars: `name`, `description`,
  `required_scope` (= `"memory.read"` — no `memory.admin` Cognito scope exists yet; comment that RBAC
  permission is the real control), `InputModel`, `OutputModel`, `required_permission: ClassVar[Permission]`,
  `audit_action: ClassVar[AuditAction]`.
- `__init_subclass__` guard: raise `TypeError` at class-definition time if a subclass defines `__call__`
  (check `"__call__" in cls.__dict__`), and — for concrete subclasses that define them — if
  `required_permission` is not a `Permission` whose value starts with `"system."`, or `audit_action`
  doesn't start with `"admin."`. (Abstract intermediate classes may skip the attr checks; simplest: check
  only when the subclass defines `run` / is not abstract.)
- Subclasses implement `async def run(self, conn: asyncpg.Connection, ctx: ToolContext, inp: BaseModel) -> BaseModel`.
- `async def __call__(self, ctx, inp)` flow (final, don't let subclasses override):
  1. `async with system_tx(ctx.db_pool) as conn:` check `has_permission(conn, ctx.tenant_id, self.required_permission)`
     (from `mem_mcp.auth.rbac`). If denied: write the audit row (`result="denied"`) **in that same
     transaction, which then commits** because we leave the `async with` normally, THEN raise after the
     block: `JsonRpcError(-32603, "caller lacks required permission: <perm>", data={"missing_permission": <perm value>})`.
     The denial must happen before any input-dependent lookup so it is identical whether or not the target
     record exists. `run()` must never be called on denial.
  2. If allowed: open `system_tx`, call `run()`, write `result="success"` audit on that conn, return.
  3. If `run()` raises (JsonRpcError or other): the tx rolls back, so write a `result="error"` audit row
     on a **fresh** `system_tx` (include `error_code` = JsonRpcError code as str, or exception type name),
     then re-raise the original exception unchanged.
  - Audit attributed to the **caller**: `tenant_id=ctx.tenant_id`, `identity_id=ctx.identity_id`,
    `client_id=ctx.client_id`, `request_id=ctx.request_id`; `details={"via": "mcp", "tool": self.name,
    "required_permission": <perm value>}` (success rows may add harmless extras like `result_count`;
    never log email/query text in structlog). If `ctx.deps is None`, skip auditing (match how other tools
    handle missing deps — check them).
  - Exactly one audit row per call in each case.
- Add `"admin.find_user"` and `"admin.get_user"` to BOTH `AUDIT_ACTIONS` and the `AuditAction` Literal in
  `src/mem_mcp/audit/logger.py` (new `# admin` group).

## 3. The tools
- `src/mem_mcp/mcp/tools/admin_find_user.py`: `AdminFindUserTool(AdminTool)`, name `memsys_admin_find_user`,
  `AdminFindUserInput` (`extra="forbid"`; `query: str = Field(min_length=2, max_length=255)`,
  `limit: int = Field(20, ge=1, le=100)`), `AdminFindUserOutput(users: list[AdminUserSummary], count: int,
  request_id: str)`. Service `ValueError` → `JsonRpcError(-32602, "invalid params", data={"errors":
  [{"path": "query", "message": ...}]}) from e` (whitespace-only query like `"  a "` passes Pydantic but
  hits this).
- `src/mem_mcp/mcp/tools/admin_get_user.py`: `AdminGetUserTool`, name `memsys_admin_get_user`,
  `AdminGetUserInput(tenant_id: UUID)` (`extra="forbid"`), `AdminGetUserOutput(user: AdminUserDetail,
  request_id: str)`. `NotFoundError` → `JsonRpcError(-32602, ..., data={"errors": [{"path": "tenant_id",
  "message": "user not found"}]})`.
- Both: `required_permission = Permission.SYSTEM_MANAGE_TENANTS`, `audit_action` = `"admin.find_user"` /
  `"admin.get_user"`, `required_scope = "memory.read"`.
- Descriptions in `src/mem_mcp/mcp/tool_descriptions.py` in house style (80–250 words; what it does,
  "Call when:", "Do not call for:", "Examples: … → …"; mention it requires the system_admin operator
  permission and is audited). Check whether any test validates description word counts/structure and
  satisfy it.
- Register both in `src/mem_mcp/main.py` (import + add to the tool list under a `# admin` comment; update
  the stale tool-count comment if trivial).
- Team roles must never confer `system.*` permissions — don't touch `ROLE_PERMISSIONS`; a team owner is
  refused (test it).

## 4. Tests (new files only)
Use the `pg_pool` fixture; UUID-suffixed emails/team names; never assume empty tables. Build `ToolContext`
directly with `ToolDeps(embeddings=<stub>, audit=DbAuditLogger(), quotas=NoopQuotas())` (see existing tool
tests for construction). Assert DB state for audit rows (query `audit_log` by `request_id` — use a unique
request_id per call).
- `tests/unit/test_admin_service.py` (DB-free parts): `_escape_like` cases (`%`, `_`, `\`, `\%` → `\\\%`),
  `_clamp_limit` (None→20, 0→1, -5→1, 9999→100, 50→50), 1-char / whitespace query → ValueError.
- DB-backed service tests: case-insensitive email and display_name match; newest first; `%%`, `_`,
  `' OR 1=1 --`, `'; DROP TABLE tenants; --`, and a backslash query match nothing (or only the literal
  user you created with such characters in display_name — include one positive literal-match case, e.g.
  display_name containing `50%_off\x`); limit 9999 → ≤ 100 rows; get_user returns system_roles incl.
  `system_admin` and teams from team_role_assignments (active only, soft-deleted team excluded, revoked
  assignment excluded); unknown tenant → NotFoundError; pooled-connection test: use a pool with
  `max_size=1` (or reuse the same connection), run a `tenant_tx` that raises to roll back, then call the
  service on the same connection under `system_tx` and get correct results.
- `tests/security/test_admin_tools_authz.py` (`pytestmark = pytest.mark.security`): non-admin caller and
  team **owner** caller → both tools raise JsonRpcError -32603 with `data == {"missing_permission":
  "system.manage_tenants"}`; `run()` never reached (monkeypatch the tool's `run` to fail/flag); exactly one
  `audit_log` row with `result='denied'`, correct action, caller's tenant_id/identity_id, `details->>'via'
  = 'mcp'`, `required_permission` present; denial identical for an existing vs a random tenant_id
  (get_user). system_admin caller → find_user matches case-insensitively with correct `count`, one
  `success` row; get_user returns `system_roles` containing `system_admin`; unknown tenant → -32602 and one `error` row; 1-char-ish
  query (`" a "`) → -32602. Also: defining an `AdminTool` subclass that overrides `__call__` raises
  `TypeError`; non-`system.*` permission or non-`admin.` audit action raises `TypeError`.
  Also go through `ToolRegistry.dispatch` once (registry with both tools registered) to prove end-to-end
  wiring, including input validation (`limit=9999` → -32602 at the Pydantic layer is fine).
- Look at how existing tests create tenants / system roles / teams / team_role_assignments (e.g.
  `tests/unit/test_bootstrap_system_admin.py`, `tests/integration/test_teams_foundation_spec1.py`,
  `tests/unit/test_rbac_resolver.py`) and reuse the approach.

## Verification (report exact results)
1. `pytest -q -p no:cacheprovider tests/unit/test_admin_service.py tests/security/test_admin_tools_authz.py <any other new files>`
2. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py tests/unit/test_main.py tests/unit/test_mcp.py tests/unit/test_audit.py`
3. Full suite `pytest -q -p no:cacheprovider` — **before** your changes (`git stash` or note from a first
   run) and after; report the list of failing test ids both times so we can confirm no new failures.
4. `ruff check src tests` and `ruff format --check` on your new files; `mypy` (report new errors only vs baseline).

Report: files changed, test commands + pass/fail counts, the before/after failing-test lists, and any
uncertainties (e.g. RLS behaviour you discovered under `system_tx`).
