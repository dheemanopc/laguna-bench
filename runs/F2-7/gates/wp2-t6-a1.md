## Gate for wp2-t6-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 3 passed in 1.73s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 304:+import asyncpg  # type: ignore[import-untyped]
    added: 336:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
