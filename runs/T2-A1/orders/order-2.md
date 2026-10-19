# Work order 2 — verify order 1 (run everything)

Your order-1 code changes look right on review; keep the design. Last session, Bash was
unavailable, so nothing was verified. This session's job is to **run** the verification and fix
whatever breaks. Use Bash for each command below and paste the exact summary lines into your report.

1. `alembic upgrade head` (uses `MEM_MCP_DB_MAINT_DSN`), then `alembic downgrade -1`, then
   `alembic upgrade head` again. Confirm `alembic current` shows `0035_memory_readable_by`.
2. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py`
3. `pytest -q -p no:cacheprovider tests/integration/test_references_memory_readable_by.py`
   — fix any failures in *your* new code or tests. For example: the memory INSERT may need
   `source_client_id`, check the SDK error's attribute name (`.code`), and check `ToolContext`
   constructor args.
4. `pytest -q -p no:cacheprovider tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py`
5. Full suite: `pytest -q -p no:cacheprovider tests`. Record the pass/fail counts and the failing test ids.
6. Baseline comparison: first `git stash -u`, then run `pytest -q -p no:cacheprovider tests` again and
   record the failing ids. Leave the DB at 0035; the function is additive. Run `git stash pop`
   afterwards, then confirm with `git status` that all your files are back. Report the set difference:
   failures present with your change but not at baseline. That set must be empty, apart from the repro
   test, which should flip from fail to pass.
7. `ruff check src tests`, `ruff format --check` on the files you changed, and `mypy`. Fix
   any findings in files you changed. Remove `# type: ignore` comments that mypy reports as unused,
   or narrow the output type with `assert isinstance(out, RefsInOutput)` instead.

Do not modify existing tests. Report the exact command outputs (summary lines) and the files changed.
