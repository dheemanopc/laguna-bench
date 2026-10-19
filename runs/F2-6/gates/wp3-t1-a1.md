## Gate for wp3-t1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 20 passed, 15 warnings in 1.86s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 14:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
