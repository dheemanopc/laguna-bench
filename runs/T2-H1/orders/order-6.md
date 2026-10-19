# Work order 6 — two tiny edits + verification run

1. In `tests/integration/test_references_access_regression.py`, remove the unused
   `if TYPE_CHECKING: import asyncpg` block and the now-unused `TYPE_CHECKING` import. Ruff flags it as F401,
   and mypy may report the ignore as unused. Use the Edit tool.
2. Delete `tests/integration/test_user_can_read_memory_regression_01a54.py`. It is your own superseded file
   from round 1. If the shell is refused, overwrite it with the Write tool? No, do not do that. Just report
   the refusal instead.

Then try each of the following shell commands as its own Bash call. Use the default permission flow and do not
assume refusal before trying. For each one, paste the output, or the exact refusal message if it is refused:
- `rm -f tests/integration/test_user_can_read_memory_regression_01a54.py`
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_regression.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
- `ruff format tests/integration/test_references_access_regression.py && ruff check src tests alembic`
- `mypy tests/integration/test_references_access_regression.py src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py`
- `pytest -q -p no:cacheprovider tests 2>&1 | tail -3`

If any test in the new file fails, fix the test or report a real bug in `src/`.
