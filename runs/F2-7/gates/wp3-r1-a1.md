## Gate for wp3-r1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 58 passed, 43 warnings in 4.07s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 45:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
