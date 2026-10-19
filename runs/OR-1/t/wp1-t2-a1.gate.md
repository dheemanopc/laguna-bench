## Gate for wp1-t2-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 
    (some tests skipped — check they are not skipped on purpose)
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 22:+import asyncpg  # type: ignore[import-untyped]
    added: 675:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
