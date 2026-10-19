## Gate for wp2-t2-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 1 passed in 1.33s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 31:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
