## Gate for wp1-g1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 46 passed in 3.81s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 1:+    import asyncpg  # type: ignore[import-untyped]
    added: 2:+import asyncpg  # type: ignore[import-untyped]
    added: 4:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
