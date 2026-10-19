## Gate for wp5-t2a-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 6 passed in 3.52s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 18:+import asyncpg  # type: ignore[import-untyped]
    added: 59:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
