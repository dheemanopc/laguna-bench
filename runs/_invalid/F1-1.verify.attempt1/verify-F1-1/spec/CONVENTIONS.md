# Memsys (mem-mcp) — codebase conventions

Python 3.12 · FastAPI · asyncpg · Postgres 16 + pgvector · Alembic · Pydantic v2 · pytest (asyncio_mode=auto).
Package: `src/mem_mcp`. Read `GUIDELINES.md` (engineering rules) and, for design intent,
`MEMORY_MCP_LLD_V1.md` (the LLD wins over the older spec) and `docs/` (ADRs, design docs).

## Layering

```
MCP transport (mcp/transport.py) → ToolRegistry (mcp/registry.py: scope check, dispatch)
  → tool class (mcp/tools/<name>.py: validate input, open tx, map errors)
    → domain/service module (memory/, teams/, mindmap/, identity/, plugins/ …: SQL + rules)
      → asyncpg connection from mem_mcp.db.tenant_tx / system_tx
web/ (FastAPI handlers for the dashboard) and jobs/ (systemd-timer jobs) call the same domain modules.
```
- Tools stay thin; SQL and business rules live in the domain module (e.g. `mindmap/service.py`,
  `teams/assignments.py`, `teams/references.py`). Domain modules take an `asyncpg.Connection`,
  never import FastAPI or `JsonRpcError`, and raise their **own exception types**
  (e.g. `RoleNotFoundError`, `ReferenceTargetNotFoundError`) which the tool maps to `JsonRpcError`
  and the web layer maps to `HTTPException`.
- External systems (Bedrock, Cognito, clock, Ollama) sit behind narrow `Protocol`s; tests wire fakes.
  Tools reach them through `ctx.deps` (`ToolDeps`: `embeddings`, `audit`, `quotas`, `nli`).

## MCP tools

- One module per tool in `src/mem_mcp/mcp/tools/`, shared helpers in `_`-prefixed modules
  (`_base.py`, `_deps.py`, `_mindmap_common.py`).
- A tool is a class with ClassVars `name` (snake_case, families prefixed: `memory_*`, `memsys_*`,
  `mindmap_*`), `description = TOOL_DESCRIPTIONS["<name>"]`, `required_scope`
  (`memory.read` | `memory.write`), `InputModel`, `OutputModel`, and
  `async def __call__(self, ctx: ToolContext, inp: BaseModel) -> BaseModel` that starts with
  `assert isinstance(inp, <Input>)`.
- Input/Output are Pydantic models named `<Tool>Input` / `<Tool>Output`; inputs usually
  `model_config = ConfigDict(extra="forbid")`, constraints via `Field(...)`/`Literal[...]`/validators.
  Defaults should be the safe/cheap behaviour. Outputs carry `request_id=ctx.request_id`.
- Descriptions live in `mcp/tool_descriptions.py` in the house style: what it does, "Call when: …",
  "Do not call for: …", "Examples: … → …". Changing behaviour means updating the description.
- Registration: import the class in `src/mem_mcp/main.py` and add it to the tool list given to
  `ToolRegistry` (grouped by family with a comment).
- `ToolContext` carries `request_id, tenant_id, identity_id, client_id, scopes, db_pool, deps`.

## Error model (`mcp/errors.py`, spec §9.4)

- Raise `JsonRpcError(code, message, data=...)`.
  - `-32602` invalid params / not found / wrong state: `data={"errors": [{"path": ..., "message": ...}]}`
    or a `data["code"]` for specific cases (e.g. `memory_not_accessible`, `map_not_live` are -32602).
  - `-32000` application errors, distinguished by `data["code"]` (e.g. `insufficient_scope`,
    `quota_exceeded`, `rate_limited`).
  - `-32603` internal / permission refusals by RBAC gates; RBAC denials put the permission string in
    `data={"missing_permission": "<perm>"}`.
- Cross-boundary lookups are **opaque**: "not found" and "no access" must be indistinguishable
  (same code, same data) so tools cannot be used as existence oracles.
- Map domain exceptions with `raise JsonRpcError(...) from e`.

## Database, tenancy, RLS

- `async with tenant_tx(pool, tenant_id) as conn:` — transaction + `SET LOCAL app.current_tenant_id`;
  RLS policies filter on it. Use for anything acting on behalf of a user.
- `async with system_tx(pool) as conn:` — transaction, no tenant GUC (BYPASSRLS role in prod). Only for
  jobs and deliberately cross-tenant code; such code must filter in SQL itself.
- Defence in depth: RLS **and** an explicit `WHERE tenant_id = $n` on per-tenant tables. The linter
  `tools/lint_tenant_scope.py` enforces this (exempt list with a justification comment for intentional
  exceptions); `tests/unit/test_lint_tenant_scope.py::…::test_real_codebase_is_clean` runs it on `src/`.
- After ROLLBACK, custom GUCs read back as `''`, not NULL: never cast the GUC bare — use
  `safe_current_tenant_id()` / `NULLIF(current_setting(...), '')::uuid` in SQL.
- Raw SQL with asyncpg `$1..$n` parameters only (no string interpolation of values). JSONB may come
  back as `str` on some statements — parse defensively (see `MemoryRecord._parse_jsonb`).
- Team access: RBAC assignments live in `team_role_assignments` (+ `roles_catalog`); effective access
  is materialised in `user_effective_team_access`; permissions per role in
  `auth/permissions.py::ROLE_PERMISSIONS`, resolved by `auth/rbac.py::has_permission`.
- Versioning: `decision`/`fact` are versioned (new row, `supersedes`/`superseded_by`, `is_current`);
  other types are edited in place (`memory/versioning.py`, ADR-0005/0007).

## Migrations

- Alembic, forward-only, one new file per change: `alembic/versions/NNNN_YYYY_MM_DD_<slug>.py` with
  `revision = "NNNN_<slug>"` chained via `down_revision`; SQL via `op.execute(sa.text(...))`; provide a
  `downgrade()`. New tables follow the peer pattern: ENABLE RLS, tenant policy, `GRANT … TO mem_app`.
  SQL helpers used by RLS are `SECURITY DEFINER` with NULLIF-guarded GUC reads.
- Docstring at the top explains *why* (the incident/decision), as the existing migrations do.

## Audit & logging

- Mutating/sensitive operations call `await ctx.deps.audit.audit(conn, action=..., result=..., tenant_id=...,
  identity_id=..., client_id=..., request_id=..., details={...})`. `action` must be a member of the
  `AuditAction` Literal in `audit/logger.py` (add new ones there). The audit row rides the operation's
  transaction, so it rolls back with it — failure audits that must survive go on a fresh transaction.
- Logs: structlog via `mem_mcp.logging_setup.get_logger`; never log memory content, secrets or tokens —
  ids, lengths, hashes only.

## Style

- `from __future__ import annotations`; full type hints (mypy strict-ish); ruff-formatted, ~100 cols.
- Module docstring explains purpose and the *why* behind non-obvious choices; comments explain intent,
  incidents and rejected alternatives rather than restating code.
- Constants UPPER_CASE at module top; private helpers `_leading_underscore`.

## Tests

- `tests/unit` (fast; DB-free or DB-backed), `tests/integration` (real Postgres end-to-end through tools /
  plugin SDK), `tests/security` (`pytestmark = pytest.mark.security`, tenant isolation & authz).
- Live DB via the `pg_pool` fixture (`tests/conftest.py`), which skips when `MEM_MCP_TEST_DSN` is unset;
  `tests/integration/conftest.py` adds e.g. `sdk_client_factory`. Async tests need no decorator
  (asyncio_mode=auto), though many files set `pytestmark = pytest.mark.asyncio`.
- The test DB is shared and not reset between tests: create your own tenants/teams with
  **UUID-suffixed** emails/names, never assume empty tables, clean up or tolerate leftovers.
  (Several pre-existing tests collide on hard-coded emails — they are known red; don't copy that.)
- Tool tests build a `ToolContext` directly with `ToolDeps(embeddings=<stub>, audit=NoopAuditLogger()
  or DbAuditLogger(), quotas=NoopQuotas())`; the stub embedder returns
  `EmbedResult(vector=[...]*1024, input_tokens=n)`. Rows in `memories` need an `oauth_clients` row for
  `source_client_id` and a team (tenant_identities.default_team_id) — see
  `tests/integration/test_mindmap_e2e.py` for a complete fixture.
- Never call real AWS/Bedrock/Cognito/Ollama (GUIDELINES §1.2). Assert behaviour (DB state, outputs,
  error code + data), not just "no exception". Regression tests name the bug in the docstring.
- Run: `pytest -q -p no:cacheprovider <paths>` with `MEM_MCP_TEST_DSN` (and `MEM_MCP_DB_MAINT_DSN` for
  `alembic upgrade head` when you add a migration).
