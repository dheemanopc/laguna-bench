# Work order 2 — fix the admin lookup implementation to match the spec

Review of round 1 found the implementation diverges from the required contract in many places. The
contract below is **exact** — external acceptance tests will call these names/signatures/fields. Please
rewrite the affected code to match it precisely; don't keep the round-1 shapes "for compatibility".

## A. `src/mem_mcp/admin/service.py` — required changes

1. Signatures (keyword-only args after `conn`):
   ```python
   async def find_users(conn, *, query: str, limit: int | None = None) -> list[AdminUserSummary]
   async def get_user(conn, *, tenant_id: UUID) -> AdminUserDetail
   def _escape_like(raw: str) -> str          # keep current logic, rename param to `raw`
   def _clamp_limit(limit: int | None) -> int  # None -> 20; else max(1, min(100, limit))
   ```
   `_clamp_limit(0) == 1`, `_clamp_limit(-5) == 1`, `_clamp_limit(9999) == 100`, `_clamp_limit(None) == 20`.
   (Round 1 returned 20 for <1 — wrong.)
2. Query validation: `q = query.strip()`; `if len(q) < 2: raise ValueError("query must be at least 2 characters")`.
   Raise plain `ValueError` (not `AdminError`).
3. Models — replace the round-1 models with exactly these (Pydantic, `tenant_id` and ids as **str**):
   ```python
   class AdminUserSummary(BaseModel):
       tenant_id: str
       email: str
       display_name: str | None
       status: str
       created_at: datetime
       provider: str | None          # primary identity
       workspace_domain: str | None  # primary identity
       default_team_id: str | None   # primary identity

   class AdminUserTeam(BaseModel):
       team_id: str
       team_name: str
       role_key: str

   class AdminUserDetail(AdminUserSummary):
       system_roles: list[str]       # sorted, from tenant_system_roles
       teams: list[AdminUserTeam]
   ```
4. `find_users` SQL — one row per tenant (round 1 joined ALL identities and ALL system roles, producing
   duplicate rows per tenant). Use the tenant's email/display name; primary identity via LEFT JOIN:
   ```sql
   SELECT t.id, t.email, t.display_name, t.status, t.created_at,
          ti.provider, ti.workspace_domain, ti.default_team_id
   FROM tenants t
   LEFT JOIN tenant_identities ti ON ti.tenant_id = t.id AND ti.is_primary
   WHERE t.email ILIKE $1 ESCAPE '\'  OR  t.display_name ILIKE $1 ESCAPE '\'
   ORDER BY t.created_at DESC, t.id
   LIMIT $2
   ```
   (In the Python triple-quoted string that's `ESCAPE '\\'` as you have now.) Convert UUIDs with `str(...)`,
   `default_team_id` → `str(...)` or None.
5. `get_user`: same SELECT shape with `WHERE t.id = $1` and the **LEFT JOIN** (a tenant without a primary
   identity must still be returned, not NotFound). NotFound only when no tenants row. `system_roles`:
   `SELECT role FROM tenant_system_roles WHERE tenant_id = $1 ORDER BY role` → list. Teams query: keep yours
   but select `tm.id AS team_id, tm.name AS team_name, rc.role_key`, `ORDER BY tm.name, tm.id`.
6. Update the module docstring accordingly (round 1 mentions identity-email search / last_seen ordering).

## B. `src/mem_mcp/mcp/tools/_admin_base.py` — required changes

1. `run` signature is **`async def run(self, conn: asyncpg.Connection, ctx: ToolContext, inp: BaseModel) -> BaseModel`**
   (conn first). Update both tools.
2. `required_permission: ClassVar[Permission]` (the enum, not `.value` string). Tools set
   `required_permission = Permission.SYSTEM_MANAGE_TENANTS`. Use `self.required_permission.value` wherever a
   string is needed (error data, audit details).
3. `audit_action: ClassVar[AuditAction]`.
4. `__init_subclass__` must enforce (raise `TypeError`):
   - `"__call__" in cls.__dict__` → TypeError("admin tools implement run(), not __call__"). **This is the key
     guarantee and round 1 omitted it.** Also decorate the base `__call__` with `@typing.final`.
   - Only for concrete tools (`"name" in cls.__dict__`), require: `run` overridden (i.e. `cls.run is not AdminTool.run`),
     `required_permission` is a `Permission` and its value starts with `"system."`, `audit_action` is a str
     starting with `"admin."`. (Don't require attrs in every subclass's own `__dict__` — that blocks
     intermediate abstract bases.)
5. Audit `details` must ALWAYS include `{"via": "mcp", "tool": self.name, "required_permission": self.required_permission.value}`
   merged with hook extras — on denied, success and error rows. Round 1 wrote `{}` for denied/success. Build
   it in one helper so it can't be forgotten.
6. Denied path: do the permission check and the denied audit **in the same `system_tx`** (write the audit
   inside the `async with` when denied, let it commit), then raise after the block. The JsonRpcError:
   `JsonRpcError(-32603, f"caller lacks required permission: {perm}", data={"missing_permission": perm})`
   (same message format as `mcp/registry.py`). The denied audit must NOT include anything derived from the
   input that would differ by whether the target exists — `target_id` from the input is fine (it's the
   caller's own input), but don't look anything up.
7. Error audit row: set `error_code` (the AuditLogger accepts `error_code`): for `JsonRpcError` use
   `str(exc.code)`, otherwise `type(exc).__name__`. Don't put the raw exception message in details (it may
   contain the search query/PII); `exc_type` is fine.
8. Success hook: allow the subclass to add details computed from the output, e.g.
   `def audit_details(self, inp: BaseModel, out: BaseModel | None) -> dict[str, Any]` (default `{}`).
   find_user adds `{"query_length": len(inp.query), "result_count": out.count}` (out may be None on
   denied/error → only query_length). get_user: target via existing `_audit_target_id` hook,
   `audit_target = "tenant"` (it is a tenant id, not "user").
9. Keep the `DbAuditLogger` fallback when `ctx.deps is None`.

## C. Tools
- `AdminFindUserInput.query = Field(..., min_length=2, max_length=255)` (round 1 had 1/256).
- `AdminFindUserOutput(users: list[AdminUserSummary], count: int, request_id: str)` — add `count = len(users)`.
- find_user maps only `ValueError` → -32602 (`data={"errors":[{"path":"query","message":str(exc)}]}`).
- get_user maps `NotFoundError` → `JsonRpcError(-32602, "user not found", data={"errors":[{"path":"tenant_id","message":"not found"}]})`
  (don't echo exception text). Drop the `(AdminError, ValueError)` branch unless something can raise it.
- Call the service with keywords: `find_users(conn, query=inp.query, limit=inp.limit)`, `get_user(conn, tenant_id=inp.tenant_id)`.
- Check `tool_descriptions.py` entries still describe the behaviour correctly (fields, 2-char minimum, ordering
  newest signup first, teams from RBAC assignments, system_admin required) and fix if not.

## D. Tests — update your new test files to the new contract and ADD the missing ones
Existing new tests must be adjusted for the signatures/fields above. Required additional coverage (round 1
lacked these):

`tests/unit/test_admin_service_helpers.py` (DB-free):
- `_clamp_limit(None)==20`, `0→1`, `-5→1`, `9999→100`, `50→50`.
- `_escape_like("a\\%")` (Python literal; i.e. chars `a\%`) `== "a\\\\\\%"` (chars `a\\\%`); `"%%" → "\\%\\%"`.
- `AdminTool` subclass that defines `__call__` → `TypeError` (use `pytest.raises(TypeError)` around a class statement).
- concrete subclass with `required_permission = Permission.TEAM_...` (any non-system perm) → TypeError;
  with `audit_action = "memory.get"` → TypeError; without `run` → TypeError.
- `AdminFindUserTool` / `AdminGetUserTool` have `required_permission is Permission.SYSTEM_MANAGE_TENANTS`,
  `required_scope == "memory.read"`, and neither defines `__call__` in its `__dict__`.
- For every **team** role key in `ROLE_PERMISSIONS` (i.e. not `system_admin`/`system_support`), no permission
  value starts with `"system."`.
- Input model: query of 1 char → ValidationError; 256 chars → ValidationError; limit 0 / 101 → ValidationError;
  extra field → ValidationError.

`tests/unit/test_admin_service_db.py` (DB-backed, UUID-suffixed data):
- case-insensitive match on email (query upper-cased) and on display_name; result exposes all summary fields
  (provider/workspace_domain/default_team_id from primary identity); a user with 2 identities appears **once**.
- newest signup first (create 2 matching tenants, set `created_at` explicitly, assert order).
- `%%` query: create a tenant with a unique suffix; `find_users(query="%%", limit=100)` must not return it,
  and every returned row must literally contain `%%` in email or display_name.
- `_` literal: display names `"zz<uuid>a_b"` and `"zz<uuid>axb"`; query `"<uuid>a_b"` returns only the first.
- backslash literal: display name containing `x\y` vs `xy`; query containing `x\y` matches only the first.
- injection probe `"' OR 1=1 --"` and `"'; DROP TABLE tenants; --"` → no error, returns rows that literally
  contain the text only (i.e. none of yours), and `tenants` still exists.
- `limit=9999` → `len(result) <= 100` (create enough matching rows? not needed — just assert ≤100 with a
  broad-ish query like `"@"`... note `@` is 1 char; use `".c"` or similar 2-char query).
- 1-char query `"a"` and `"  a  "` → ValueError.
- get_user: system_roles == ["system_admin"] when granted, [] otherwise; teams from team_role_assignments with
  correct team_name + role_key; a `revoked` assignment and an assignment on a soft-deleted team are excluded;
  tenant without identity rows is still returned; random UUID → NotFoundError.
- GUC regression: keep yours, but make sure it calls BOTH `find_users` and `get_user` on the very same
  connection after the rolled-back set_config, and asserts the GUC reads `''` first.

`tests/security/test_admin_tools_authz.py` (`pytestmark = pytest.mark.security`), `DbAuditLogger`, unique
request_id per call:
- Non-admin denied, **both tools**: exc.code == -32603, `exc.data == {"missing_permission": "system.manage_tenants"}`;
  `run()` not reached — `monkeypatch.setattr(AdminFindUserTool, "run", <async fn that sets a flag / raises AssertionError>)`;
  exactly one audit row for the request_id with `result='denied'`, correct `action`, `tenant_id` = caller,
  `actor_identity_id` = caller identity, `details->>'via'='mcp'`, `details->>'tool'`, `details->>'required_permission'='system.manage_tenants'`.
- get_user denial for an existing tenant id vs `uuid4()` → identical `(code, data)`.
- Team **owner** (active owner assignment) → denied identically.
- system_admin success: find_user case-insensitive match, `count == len(users)`, exactly one audit row
  `result='success'`, `action='admin.find_user'`, details include via/tool/required_permission/result_count;
  get_user returns `system_roles` containing `"system_admin"` for the admin's own tenant and one success row.
- system_admin get_user unknown tenant → -32602 and exactly one `error` row (with `error_code='-32602'`).
- system_admin find_user `"  a "` → -32602 and one `error` row.
- Dispatch through `ToolRegistry().register(...)` + `registry.dispatch(ctx, "memsys_admin_find_user", {...})`
  returns a JSON-serialisable dict with `users`/`count`; dispatch with `{"query": "a"}` → -32602 from validation.
- Registration in `main.py`: if there's an existing test pattern for checking registered tool names, add an
  assertion for both names; otherwise skip and tell me.

## Verification — report exact commands and results
1. `pytest -q -p no:cacheprovider tests/unit/test_admin_service_helpers.py tests/unit/test_admin_service_db.py tests/security/test_admin_tools_authz.py`
2. `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py`
3. `ruff check src tests tools` and `mypy` (project config) — clean.
4. Full suite `pytest -q -p no:cacheprovider` — list failing test IDs and confirm each one also fails on a clean
   baseline (`git stash -u` → run → `git stash pop`; make sure you restore your work).
