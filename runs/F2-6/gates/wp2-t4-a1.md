## Gate for wp2-t4-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 3 passed in 1.65s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 285:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
