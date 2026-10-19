# Work order 5 — apply order 4 (nothing was changed last round)

Last round no file was modified. File edits do NOT need the shell: use your Edit/Write tools to change
`tests/integration/test_references_access_regression.py` directly. Make every edit listed in
`order-4.md` items 2–5 (also summarised below), then *attempt* each shell command. If a command is
refused, paste the exact refusal text and continue with the next step. Do not stop early.

Edits to make in `tests/integration/test_references_access_regression.py` (Edit tool):
- Annotate every test method's fixture parameters (`pg_pool: Any`, `sdk_client_factory: Any`).
- Fix the `ToolContext` construction to match the declared types in `src/mem_mcp/mcp/tools/_base.py`
  (`scopes` type) and `ToolDeps` in `_deps.py` (`embeddings` must be a stub object satisfying the
  protocol, not None; copy the stub embedder pattern used by an existing test, found by grepping `tests/` for `EmbedResult`).
  To avoid repeating it, factor this into one helper, `_tool_ctx(pool, tenant_id, client_id) -> ToolContext`.
- After every tool call, `assert isinstance(result, RefsInOutput)` / `RefsOutOutput`, and import these.
- `_create_memory` must return a properly typed `UUID`.
- `test_backfill_user_cites_own_memory_succeeds`: remove the `system_tx` wrapper and the now-unused
  `system_tx` import. Assert `refs[0].target_memory_id == str(m1)`, `refs[0].source_memory_id == str(m2)`,
  and `inaccessible_count == 0` for both tools.
- `test_cross_tenant_write_same_error_opacity`: switch to `pytest.raises(PluginValidationError)`, assert
  `code == "memory_not_accessible"` for both, and keep the equality assertions.
- Define `plugin_id` / `owner_plugin` / `outsider_plugin` BEFORE `try:` in the e2e tests.

Then run, in order. Each step is a separate shell call:
1. `rm -f tests/integration/test_user_can_read_memory_regression_01a54.py`
2. `ruff format tests/integration/test_references_access_regression.py && ruff check src tests alembic`
3. `mypy tests/integration/test_references_access_regression.py src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py`
4. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_regression.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
5. The before/after full-suite comparison exactly as in order-4 item (c), with the `diff` output pasted.
