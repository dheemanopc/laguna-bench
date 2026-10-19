## Gate for wp1-t2-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 11 passed in 1.75s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 15:+import asyncpg  # type: ignore[import-untyped]
    added: 332:+            return new_id  # type: ignore[no-any-return]
    added: 342:+    return existing  # type: ignore[no-any-return]
    added: 389:+import asyncpg  # type: ignore[import-untyped]
    added: 437:+        return await conn.fetchval(  # type: ignore[no-any-return]
RESULT: FAIL
