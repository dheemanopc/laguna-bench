# Work order 1 — Admin user lookup over MCP (`memsys_admin_find_user` / `memsys_admin_get_user`)

Read `CLAUDE.md` and `CONVENTIONS.md` first; follow them (layering, error model, tool structure, audit,
tests with UUID-suffixed data). No schema migration. Do not modify existing tests.

## Goal
Operators holding the `system_admin` system role need two **read-only**, cross-tenant MCP tools to look
users up ("who is manasi, and what teams is she in?"). Build them on a reusable `AdminTool` base so
future admin tools cannot ship without the permission check.

## 1. Transport-agnostic service: new package `src/mem_mcp/admin/`
- `__init__.py` (short docstring).
- `errors.py`: `AdminError(Exception)` base, `NotFoundError(AdminError)`. **No FastAPI / JsonRpcError
  imports anywhere in this package** (also don't import `mem_mcp.auth.rbac`, which pulls in FastAPI).
- `service.py` (takes an `asyncpg.Connection`, does NOT authorize — callers gate first; say so in the docstring):
  - Pydantic models, e.g. `AdminUserSummary` and `AdminUserDetail(AdminUserSummary)` + `AdminUserTeam`.
    Summary fields: `tenant_id: str`, `email`, `display_name` (nullable), `status`, `created_at`,
    and from the **primary** identity (`tenant_identities.is_primary`): `provider`, `workspace_domain`,
    `default_team_id` (nullable; str or UUID — pick one and be consistent). Use LEFT JOIN so a tenant
    without a primary identity still appears (those fields then None). Check the real column names in
    `alembic/versions/0001_initial_schema.py` and later migrations.
  - `def _escape_like(raw: str) -> str`: backslash-escape `\` FIRST, then `%` and `_`.
  - `def _clamp_limit(limit: int | None) -> int`: `None` → 20; otherwise clamp into 1..100 (never raise).
    Module-level constants for 20/100/2.
  - `async def find_users(conn, *, query: str, limit: int | None = None) -> list[AdminUserSummary]`:
    strip query; if `len < 2` raise `ValueError`. Case-insensitive substring match on email OR
    display_name using `ILIKE $1 ESCAPE '\'` with the pattern `'%' + _escape_like(q) + '%'` built in
    Python and passed as a parameter (no string interpolation of values into SQL). Order
    `created_at DESC` (newest signup first; add a tiebreaker such as `id`). `LIMIT $2` with clamped limit.
  - `async def get_user(conn, *, tenant_id: UUID) -> AdminUserDetail`: summary fields +
    `system_roles: list[str]` (sorted, from `tenant_system_roles`) + `teams: list[AdminUserTeam]`
    (`team_id`, `team_name`, `role_key`) from **`team_role_assignments` JOIN `roles_catalog`**
    (`member_kind='user' AND member_id=$1 AND status='active'`) JOIN `teams` with `deleted_at IS NULL`
    (see `auth/rbac.py::get_team_role` for the assignment query shape). Unknown tenant → `NotFoundError`.
  - Never cast app GUCs bare. The service must work on a pooled connection that previously ran a
    rolled-back `tenant_tx` (custom GUC reads back as `''`, not NULL, after ROLLBACK) — if any RLS
    policy on the touched tables would choke on `''` under `system_tx`, report it to me rather than
    adding a migration.
- Tenant-scope linter: the service is deliberately cross-tenant. Add `"src/mem_mcp/admin/service.py"`
  to `EXEMPT_PREFIXES` in `tools/lint_tenant_scope.py` with a justification comment (same style as the
  existing entries: cross-tenant by design, only reachable via the RBAC-gated `AdminTool`, runs under
  `system_tx`). Also mention it in the service module docstring.

## 2. `AdminTool` base: `src/mem_mcp/mcp/tools/_admin_base.py`
- Abstract base class for the `memsys_admin_*` family. ClassVars: `name`, `description`,
  `required_scope = "memory.read"` (comment: no `memory.admin` scope in the Cognito resource server
  yet; the RBAC permission is the real control), `InputModel`, `OutputModel`,
  `required_permission: ClassVar[Permission]`, `audit_action: ClassVar[AuditAction]`.
- `__init_subclass__` validation (fail at import time) for concrete subclasses: `required_permission`
  must be a `Permission` whose value starts with `system.`; `audit_action` must start with `admin.`;
  a subclass defining `__call__` in its own `__dict__` must raise `TypeError` ("must implement run(),
  not override __call__"). Subclasses implement `async def run(self, conn, ctx, inp) -> BaseModel`
  (abstract in the base).
- `__call__(self, ctx, inp)` (final; flow):
  1. Open `system_tx(ctx.db_pool)` and `has_permission(conn, ctx.tenant_id, self.required_permission)`
     (from `mem_mcp.auth.rbac`). Do NOT pass/consult the input before the check, so denial is identical
     regardless of the target record.
  2. If denied: write the `result="denied"` audit row on its **own committed** `system_tx` (so it
     survives the failing call), then raise
     `JsonRpcError(-32603, "caller lacks required permission: <perm>", data={"missing_permission": <perm.value>})`
     — same convention as the plugin gate in `mcp/registry.py`. `run()` must never be reached.
  3. If allowed: inside a `system_tx` call `out = await self.run(conn, ctx, inp)`, then audit
     `result="success"` on the same conn (rides the tx), return `out`.
  4. If `run()` raises (JsonRpcError or anything else): the tx rolls back; audit `result="error"` on a
     fresh `system_tx` (with `error_code` = JsonRpcError code or exc type name), then re-raise unchanged.
  - Audit is attributed to the **caller**: `tenant_id=ctx.tenant_id`, `identity_id=ctx.identity_id`,
    `client_id=ctx.client_id`, `request_id=ctx.request_id`; `details` always include
    `{"via": "mcp", "tool": self.name, "required_permission": perm.value}`. Do not log query text in
    logs; in audit details, it is fine to include non-secret target info (e.g. `target_tenant_id` for
    get_user on success) but keep it minimal. Use `ctx.deps.audit` (handle `ctx.deps is None` by
    skipping audit gracefully, or document if you choose otherwise).
  - Exactly one audit row per call in every path.
- Add `"admin.find_user"` and `"admin.get_user"` to the `AuditAction` Literal in
  `src/mem_mcp/audit/logger.py` (check whether there is also a tuple/list of actions near it that must
  be kept in sync — there is one at ~line 35–90; add them there too if it's the canonical list).

## 3. Tools (one module each) + registration + descriptions
- `src/mem_mcp/mcp/tools/admin_find_user.py`: `AdminFindUserTool(AdminTool)`, name
  `memsys_admin_find_user`; `AdminFindUserInput(extra="forbid")`: `query: str` (min 2, max 255),
  `limit: int = 20` (ge 1, le 100). `AdminFindUserOutput`: `users: list[AdminUserSummary]`,
  `count: int`, `request_id: str`. `ValueError` from the service → `JsonRpcError(-32602, ...,
  data={"errors": [{"path": ["query"], "message": ...}]})`. Permission `Permission.SYSTEM_MANAGE_TENANTS`,
  audit_action `"admin.find_user"`.
- `src/mem_mcp/mcp/tools/admin_get_user.py`: `AdminGetUserTool`, name `memsys_admin_get_user`;
  `AdminGetUserInput(extra="forbid")`: `tenant_id: UUID`. Output `{user: AdminUserDetail, request_id}`.
  `NotFoundError` → `JsonRpcError(-32602, ..., data={"errors": [{"path": ["tenant_id"], "message": "user not found"}]})`.
  Same permission, audit_action `"admin.get_user"`.
- Register both in `src/mem_mcp/main.py` (own `# admin` group comment), and add descriptions to
  `mcp/tool_descriptions.py` in the house style ("Call when: … / Do not call for: … / Examples: … → …"),
  noting they require the `system.manage_tenants` permission (system_admin) and are read-only.
- Do NOT touch `ROLE_PERMISSIONS` — team roles must keep zero `system.*` permissions.

## 4. Tests (new files only)
- `tests/unit/test_admin_service.py` (DB-free parts + DB-backed parts):
  - `_escape_like`: `%`→`\%`, `_`→`\_`, `\`→`\\`, `a\%` → `a\\\%` (no double escaping); `_clamp_limit`:
    None→20, 0→1, -5→1, 9999→100, 50→50.
  - DB-backed (`pg_pool`): create tenants (+ primary identity, + teams/assignments where needed) with
    UUID-suffixed emails/display names. Case-insensitive match on email and on display_name; newest
    first; `%%` returns nothing that doesn't literally contain `%%`(assert none of your fixtures come back
    and result has no rows lacking `%%`), `_` literal, backslash literal (create a user whose display
    name contains a backslash and find it), SQL injection probes (`' OR 1=1 --`, `'; DROP TABLE tenants; --`)
    return nothing and tables survive; limit 9999 → ≤100 rows; 1-char / whitespace-padded 1-char query →
    `ValueError`; get_user returns system_roles, teams from `team_role_assignments` with role_key,
    excludes soft-deleted teams and non-active assignments; unknown tenant → `NotFoundError`.
  - Pooled-GUC regression: on a pool with `max_size=1` (or otherwise guaranteeing the same connection),
    run a `tenant_tx` that raises (rolled back), then call `find_users`/`get_user` via `system_tx` on
    the same connection and assert it works.
- `tests/unit/test_admin_tools.py` (or `tests/security/test_admin_tools_authz.py` with
  `pytestmark = pytest.mark.security` — your call, ideally both unit and security coverage):
  - Base-class guards: subclass overriding `__call__` → `TypeError`; non-`system.*` permission →
    error; audit_action not starting with `admin.` → error.
  - Non-admin caller (plain tenant), and a **team owner** caller: both tools raise JsonRpcError with
    `data == {"missing_permission": "system.manage_tenants"}`; a spy subclass / monkeypatched `run`
    proves `run()` is never reached; with `DbAuditLogger`, exactly one `audit_log` row for the caller
    (filter by `request_id` unique per test) with `result='denied'`, `details->>'via'='mcp'`,
    `details->>'required_permission'='system.manage_tenants'`, `details->>'tool'`.
  - No existence oracle: denied get_user for an existing tenant vs a random UUID → identical code+data.
  - system_admin caller (insert `tenant_system_roles` row role `system_admin`): find_user returns
    the match case-insensitively with correct `count`; get_user returns `system_roles` containing
    `system_admin`; exactly one `admin.find_user` / `admin.get_user` `success` audit row attributed
    to the caller's tenant_id/identity_id.
  - Tool-level: 1-char query → -32602 (call the tool directly with a model built via
    `model_construct` or through `ToolRegistry.dispatch` — via dispatch the pydantic min_length gives
    -32602 too; test the service-ValueError mapping directly, e.g. query `" a "` passes min_length 2?
    — `" a"` has length 2 but strips to 1, use that); unknown tenant → -32602; error path leaves one
    `result='error'` audit row.
  - Registration: both names are present in the registry built in `main.py` (if there's an existing
    test pattern for that, follow it).

## Acceptance / verification — run and report exact results
1. `ruff check src tests` and `mypy` — clean for new/changed files (report any pre-existing noise separately).
2. `pytest -q -p no:cacheprovider tests/unit/test_admin_service.py tests/unit/test_admin_tools.py <any security file you added>` — all pass.
3. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py` — pass.
4. Full suite `pytest -q -p no:cacheprovider` BEFORE your change (stash or note from a first run) and
   AFTER; report the failing test node IDs in both runs so I can confirm no new failures.

Report: files changed, exact test commands + pass/fail counts, any deviations from this order and why.
