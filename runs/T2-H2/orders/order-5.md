# Work order 5 — lint/type fixes in the new test file (edit only; Bash not required)

Only edit `tests/integration/test_references_access_rule.py`. No other files.
(pyproject: ruff selects I (isort, order-by-type default); mypy `files` includes `tests`.)

1. **ruff I001** — the `from mem_mcp.teams.references import (...)` block is mis-sorted. With
   ruff's default order-by-type, classes come before functions:
   ```python
   from mem_mcp.teams.references import (
       HardDeleteBlockedError,
       ReferenceTargetNotFoundError,
       caller_can_access_memory,
       check_hard_delete_with_filtered_citers,
       insert_reference,
       resolve_reference_target,
   )
   ```
2. **mypy attr-defined** — `RefsInTool.__call__` / `RefsOutTool.__call__` return `BaseModel`, so
   `out.accessible_count`, `out.refs` etc. fail type-checking. Import `RefsInOutput` /
   `RefsOutOutput` and add `assert isinstance(out, RefsInOutput)` (resp. `RefsOutOutput`) right after
   each `out = await tool(ctx, inp)`.
3. **mypy index on Optional** — in `test_e2e_opacity_not_found_vs_no_access` (and any similar spot,
   e.g. `test_resolve_opacity_not_found_vs_no_access`), `err_no_access` is `tuple | None` and is
   indexed (`err_no_access[0]`). Add `assert err_no_access is not None` and
   `assert err_not_found is not None` before the comparisons.
4. Scan the rest of the file for other obvious mypy/ruff problems of the same kinds (unused imports —
   e.g. is `UUID` still used?, unsorted imports, attribute access on `BaseModel`, indexing Optional)
   and fix them.

If Bash is available to you, also run and paste:
`ruff check tests/integration/test_references_access_rule.py`,
`ruff format --check tests/integration/test_references_access_rule.py` (format if needed),
`mypy tests/integration/test_references_access_rule.py src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py`,
`pytest -q -p no:cacheprovider tests/integration/test_references_access_rule.py tests/integration/test_references_own_memory_repro.py`.
If Bash is not available, just make the edits and say so — do not ask for permission.
