## Gate for wp1-t2-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 4 passed in 1.26s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 9:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
