## Gate for wp1-t2-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 7 passed in 1.37s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 15:+import asyncpg  # type: ignore[import-untyped]
    added: 577:+    return wf_id  # type: ignore[no-any-return]
    added: 638:+import asyncpg  # type: ignore[import-untyped]
    added: 666:+            return tid  # type: ignore[no-any-return]
    added: 686:+            return tid  # type: ignore[no-any-return]
RESULT: FAIL
