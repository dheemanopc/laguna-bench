# Work order 3 — apply fix 1 with Edit/Write, then try to verify

1. Apply fix 1 from order 2 (reorder the checks in `src/mem_mcp/mcp/tools/mindmap_resolve.py`, and add
   the test "node of another map + valid resolver → -32602 path node_id, nothing changed" to
   `tests/integration/test_mindmap_resolve_e2e.py`). Use the Edit/Write file tools, not Bash heredocs.
   Keep the code mypy/ruff-clean by inspection: line length ≤100, typed, and no unused imports.
2. Then try each of the following as a separate, simple Bash command. Run each one exactly once, and
   don't chain with `&&`. If a command is denied, note "denied" and move on to the next:
   - `alembic upgrade head`
   - `alembic current`
   - `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py`
   - `pytest -q -p no:cacheprovider tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py`
   - `pytest -q -p no:cacheprovider tests/unit tests/integration`
   - `ruff check src tests`
   - `ruff format --check src tests`
   - `mypy`
   If a command runs and shows failures in our code or tests, fix them and rerun that command.
3. Carefully re-read your new test file by eye against the fixture in `tests/integration/test_mindmap_e2e.py`.
   Check the imports, the fixture names, and how `mindmap_close` is called with an empty
   `confirmed_decisions` (it's allowed: the default is an empty list). Fix anything that's obviously wrong.

Report, for each command: ran or denied, and the exact pass/fail counts.
