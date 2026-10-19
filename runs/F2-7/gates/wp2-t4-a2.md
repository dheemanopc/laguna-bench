## Gate for wp2-t4-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 9 passed in 1.72s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 116:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
