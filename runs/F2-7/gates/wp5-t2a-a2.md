## Gate for wp5-t2a-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 2 passed in 1.39s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 14:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
