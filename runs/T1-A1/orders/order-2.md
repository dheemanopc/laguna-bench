# Work order 2 — review follow-ups for the admin MCP tools

Good work on order 1; the design is right. Please make these focused fixes (do not modify pre-existing tests;
edit only the new files you added plus `_admin_base.py`).

## A. `src/mem_mcp/mcp/tools/_admin_base.py`
1. **Audit failures of the permission check itself.** If `has_permission(...)` raises (DB error etc.),
   today no audit row is written. Wrap the check so that an exception there writes exactly one
   `result="error"` row on a fresh `system_tx` (same best-effort/never-mask pattern you already use) and
   re-raises the original exception. Keep the success/denied paths exactly as they are (exactly one row
   per call in every case — make sure the run()-error path and the permission-error path can't both fire).
2. Type `_audit`'s `result` parameter as `AuditResult` (import from `mem_mcp.audit.logger`) and drop the
   `# type: ignore[arg-type]`.

## B. Tests
1. **Strong limit test** (`tests/unit/test_admin_service.py`): the current `limit=9999 → <= 100` check is
   vacuous if the shared DB has fewer than 100 matches. Create 101+ tenants sharing a UUID token
   (one `executemany` or a single `INSERT ... SELECT generate_series` is fine) and assert
   `len(find_users(conn, query=token, limit=9999)) == 100`, `limit=None → 20`, `limit=0 → 1`.
2. **Pooled-connection test through the tool** (`tests/security/test_admin_tools_authz.py`): with a
   `max_size=1` pool (same construction as your service-level test), first run a `tenant_tx` that raises
   (forcing ROLLBACK, GUC now `''`), then on that same pool call (a) `AdminGetUserTool` as a `system_admin`
   caller → success + exactly one `success` audit row, and (b) `AdminFindUserTool` as a non-admin caller
   → -32603 `missing_permission` + exactly one `denied` audit row. This proves the permission check and
   audit INSERT also survive the `''` GUC, not just the service SQL.
3. **Permission-check failure audited**: monkeypatch `has_permission` as imported in `_admin_base` to
   raise `RuntimeError`; assert the RuntimeError propagates, `run()` isn't reached, and exactly one
   `error` audit row exists for the request_id.
4. **Team roles never confer system perms** (unit, DB-free): assert that for every role key in
   `ROLE_PERMISSIONS` other than the system roles (`system_admin`, `system_support`), no granted permission
   value starts with `"system."`. Put it in the security test file or `test_admin_service.py`.

## Verification (report exact results)
- `pytest -q -p no:cacheprovider tests/unit/test_admin_service.py tests/security/test_admin_tools_authz.py`
- `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py tests/unit/test_mcp.py tests/unit/test_main.py tests/unit/test_audit.py tests/unit/test_rbac_permissions.py tests/unit/test_rbac_resolver.py`
- Full suite `pytest -q -p no:cacheprovider`: compare the failing/erroring test-id set against your saved
  `before_src_only.txt` list and report any id that is new.
- `ruff check src tests`, `ruff format --check` on changed files, `mypy`.
