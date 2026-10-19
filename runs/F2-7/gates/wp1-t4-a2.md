## Gate for wp1-t4-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 7 passed in 1.73s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 12:+import asyncpg  # type: ignore[import-untyped]
    added: 298:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
