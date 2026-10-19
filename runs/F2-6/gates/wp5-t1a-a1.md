## Gate for wp5-t1a-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 13 passed in 3.44s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 40:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
