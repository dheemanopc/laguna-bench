## Gate for wp1-t3-a1 (harness-run)
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/workflow_moves.py:14: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
- tests: 6 passed in 1.98s
RESULT: FAIL
