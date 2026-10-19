# Work order 3 — final cleanup (small)

1. `.bench_baseline.txt` is STILL in the repo (staged as added: `git status --short` shows `A .bench_baseline.txt`).
   Remove it from both the index and the working tree: `git rm -f .bench_baseline.txt`.
   If that command is blocked, try `git rm --cached .bench_baseline.txt` followed by `rm .bench_baseline.txt`,
   and report exactly what happened (command + output). Do not commit.
2. Remove the "T2-B1" tag from test docstrings/comments in `tests/integration/test_references_own_memory.py`
   and `tests/unit/test_references_own_memory.py` (and anywhere else under `src/`, `tests/`, `alembic/` you
   added it — `grep -rn "T2-B1" src tests alembic`). Replace with a plain description such as
   "regression: memory_not_accessible when citing one's own memory (raw-SQL-provisioned account)".
   Do not touch `tests/integration/test_references_own_memory_repro.py`.
3. Re-run: `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_own_memory.py tests/unit/test_references_own_memory.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py`
   and `ruff check src tests`. Report results and the final `git status --short`.
