## Gate for wp1-t3-a4 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 6 passed in 2.75s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 121:+import asyncpg  # type: ignore[import-untyped]
    added: 742:+    from asyncpg import Connection  # type: ignore[import-untyped]
RESULT: FAIL
