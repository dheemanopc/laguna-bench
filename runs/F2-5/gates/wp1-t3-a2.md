## Gate for wp1-t3-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 43 passed in 4.65s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 2951:+        import mem_mcp.mindmap.workflow_moves  # noqa: F401
RESULT: FAIL
