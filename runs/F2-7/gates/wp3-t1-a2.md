## Gate for wp3-t1-a2 (harness-run)
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/web/handlers/workflows.py:12: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
    src/mem_mcp/web/handlers/workflows.py:12: note: See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports
- tests: 14 passed, 9 warnings in 1.62s
RESULT: FAIL
