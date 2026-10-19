# Work order 2 — continue order 1 (tooling guidance)

Please carry out work order 1 in full. About the denied command:

- Use the **Read / Grep / Glob tools** (not `cat`/`grep` via Bash) to inspect the schema (`alembic/versions/`),
  `src/mem_mcp/memory/hybrid_query.py`, `src/mem_mcp/mcp/errors.py`, `tests/conftest.py`, etc.
- Run shell commands **one simple command at a time** — no `&&`, pipes, `;`, or `cd` chains. Examples:
  - `pytest -q -p no:cacheprovider tests/integration/test_memory_list_behaviour.py`
  - `ruff check tests`
  - `mypy`
  - `git status`
- If a simple `pytest` invocation is also refused, write the test files anyway (Write tool), then tell me exactly
  which command was refused and its error text, so I can sort out permissions. Do not try to work around the permission system.

For suspected bugs you cannot verify by running, do not guess with `strict=True` xfails — note them as unverified in your report.
