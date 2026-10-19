## Gate for wp1-t2-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 16 passed in 2.22s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 23:+    import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
