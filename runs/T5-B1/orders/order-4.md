# Work order 4 — verification only (previous run timed out before reporting)

Do NOT write new features. Keep this run under ~20 minutes and REPORT even if something is unfinished.
Wrap every command in `timeout` (pytest runs: `timeout 300`, full suite: `timeout 900`). If a command times out, say so and move on.

1. Delete the stray `_schema_check_tmp.py` at repo root and unstage it (`git rm -f _schema_check_tmp.py` or
   `git rm --cached` + delete). `git status` must not list it afterwards.
2. Confirm `src/mem_mcp/mcp/tools/update.py` still contains `FOR UPDATE` and the `is_current` conflict check
   (i.e. the bug-demo revert from order 3 was restored). Report `git diff --stat`.
3. Run and paste summary lines:
   - `timeout 120 alembic upgrade head`
   - `timeout 300 pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` (3 times in a row)
   - `timeout 300 pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_revision.py tests/unit/test_web_memories_handler.py tests/unit/test_embedding_status_select.py tests/unit/test_plugin_memory_client_tier1.py`
   - `timeout 900 pytest -q -p no:cacheprovider -x --timeout=120` if pytest-timeout is installed, else `timeout 900 pytest -q -p no:cacheprovider` — paste the final summary line and the list of failing test ids.
   - For the failing ids only: `git stash -u`, rerun just those ids, `git stash pop` — report which also fail on baseline (pre-existing).
   - `timeout 300 ruff check src tests`; `timeout 600 mypy`
4. Did you complete the bug demonstration in order 3 (tests fail without `FOR UPDATE`/is_current check)? If yes,
   report which tests failed. If not, do it now quickly: comment out `FOR UPDATE` and the `if not is_current:` block,
   run the concurrency file once with `timeout 300`, record results, then restore with `git diff` verification.
5. If any test fails because of our change, fix it (without modifying pre-existing tests) and report what you changed.
