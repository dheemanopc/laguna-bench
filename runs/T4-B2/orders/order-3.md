# Work order 3 — small type fix + gate re-run

1. `src/mem_mcp/mcp/tools/mindmap_resolve.py` ~line 243-252: inside the Phase-3 `if will_resolve_with_edge:`
   block that calls `insert_reference(...)`, `inp.resolved_by_memory_id` is still `UUID | None` for mypy (the
   earlier assert narrowed it only inside a different `if` block). Add
   `assert inp.resolved_by_memory_id is not None` next to the existing two asserts there (or bind a local
   `resolver_id: UUID | None = inp.resolved_by_memory_id` once at the top and branch on `resolver_id is not None`
   everywhere instead of the `will_resolve_with_edge` bool — preferred, it narrows cleanly). Also make sure
   `resolved` (Phase 2) cannot be referenced unbound.
2. Try once more to run, and report output verbatim (summary lines):
   `ruff check src tests`, `ruff format --check` on the files you created/changed, `mypy`, and
   `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_unit.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`.
   If a command is refused by the sandbox, say so plainly and move on — do not spend turns retrying.
   If ruff/mypy can't run, carefully re-read every file you created or changed for: unused imports, imports not
   sorted (isort order: stdlib, third-party, first-party `mem_mcp`), lines > 100 cols, `UUID | None` passed where
   `UUID` is required, and unused `# type: ignore`s.
