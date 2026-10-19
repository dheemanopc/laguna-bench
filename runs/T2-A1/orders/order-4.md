# Work order 4 — verification, one simple command at a time

Bash appears to be denied for compound commands (`&&`, `;`), piped commands (`|`), and
file-rewriting tools. Run **each command below as its own Bash call, exactly as written, with no
pipes, chaining or redirection**. If a command is denied, skip it, note "denied", and keep going
with the next one. Make any code fixes with the Edit tool, not with `ruff format`.

1. `ruff check src tests`
2. `ruff format --diff src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py tests/integration/test_references_memory_readable_by.py alembic/versions/0035_2026_06_01_memory_readable_by.py`
   Apply any diff it prints by hand with Edit, then rerun the command until it is clean.
3. `mypy`. Fix findings in your changed files. If the test file's `# type: ignore[attr-defined]`
   comments are reported unused, replace them with `assert isinstance(out, RefsInOutput)` /
   `RefsOutOutput` narrowing.
4. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_memory_readable_by.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py tests/unit/test_no_bare_tenant_guc_cast.py`
5. `pytest -q -p no:cacheprovider -rfE tests`
   From the short-summary section, list every FAILED/ERROR id with its one-line reason. For each one,
   say whether the reason or traceback involves `teams/references.py`, `refs_in`, `refs_out`,
   `memory_readable_by`, migration 0035, or the write tool's references path. Use Grep/Read on the
   failing test files to check. Investigate and fix anything that does, without modifying existing
   tests.

Report each command's exact summary line, the failure attribution table, and which files you changed.
