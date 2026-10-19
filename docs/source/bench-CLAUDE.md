# Working in this repository (benchmark run)

This is the Memsys codebase (`mem-mcp`): Python 3.12, FastAPI, asyncpg, PostgreSQL 16 + pgvector.
Source lives in `src/mem_mcp/`, tests in `tests/`. See `CONVENTIONS.md` for the project's established
patterns — new code must follow them (layering, error model, MCP tool structure, naming, tenant_tx/RLS usage).

## Environment
- A dedicated, freshly migrated test database is already configured in your environment
  (`MEM_MCP_TEST_DSN`, `MEM_MCP_DB_MAINT_DSN`). Do not change those variables.
- Run tests with `pytest <paths>` (e.g. `pytest tests/unit/test_x.py -q`). Run the relevant subset often;
  the full suite takes ~20s: `pytest -q`.
- Lint/type check: `ruff check src tests`, `mypy` (project config in pyproject.toml).
- Schema changes go through a new Alembic migration in `alembic/versions/`; apply with `alembic upgrade head`.
- There is no network access to external services; tests must not need it.
- Some tests in the suite were already failing before your change (pre-existing fixture issues).
  Do not try to fix unrelated pre-existing failures; make sure you do not introduce new ones.

## Rules
- Implement the work order you were given. Keep changes focused on it.
- Do not weaken, skip or delete existing tests to make things pass. Do not modify tests unless the work order asks you to.
- When done, reply with a short report: what you changed (files), how you verified it (test commands + results),
  and anything left open or uncertain.
