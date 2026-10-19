## Gate for wp1-t2-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 27 passed in 2.86s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 416:+        # asyncpg (it is untyped and would otherwise require a ``type: ignore``).
    added: 723:+            return tid  # type: ignore[no-any-return]
    added: 743:+            return tid  # type: ignore[no-any-return]
    added: 763:+            return tid  # type: ignore[no-any-return]
    added: 775:+            return tid  # type: ignore[no-any-return]
RESULT: FAIL
