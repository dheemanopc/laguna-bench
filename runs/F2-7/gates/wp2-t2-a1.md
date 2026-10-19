## Gate for wp2-t2-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 4 passed in 1.92s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 25:+import asyncpg  # type: ignore[import-untyped]
    added: 56:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
