## Gate for wp1-t1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 14 passed in 1.08s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 9:+from mem_mcp.mindmap.work_items import ReasonRequiredError  # noqa: F401
RESULT: FAIL
