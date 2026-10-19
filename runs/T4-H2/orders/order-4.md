# Work order 4 — one layering fix

In `src/mem_mcp/mcp/tools/mindmap_resolve.py` the write transaction runs raw SQL
(`SELECT state FROM memory_maps WHERE root_memory_id = $1 FOR UPDATE`). SQL belongs in
`src/mem_mcp/mindmap/service.py`. Add `async def lock_map_state(conn, *, root_memory_id, tenant_id) -> str | None`
there (`SELECT state FROM memory_maps WHERE root_memory_id = $1 AND tenant_id = $2 FOR UPDATE`) and call it from
the tool. No other changes.

Verify and report counts: `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`, `ruff check src tests`, `mypy`.
