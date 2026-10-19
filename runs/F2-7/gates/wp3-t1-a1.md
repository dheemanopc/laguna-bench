## Gate for wp3-t1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 14 passed, 9 warnings in 1.60s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 16:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
