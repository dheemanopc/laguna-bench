## Gate for wp1-t3-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 6 passed in 3.30s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 739:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
