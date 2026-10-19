## Gate for wp1-g1-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 46 passed in 3.60s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 2:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
