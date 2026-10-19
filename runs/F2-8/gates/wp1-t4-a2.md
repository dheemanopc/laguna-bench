## Gate for wp1-t4-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 8 passed in 1.59s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 47:+        return row["workflow_id"]  # type: ignore[no-any-return]
RESULT: FAIL
