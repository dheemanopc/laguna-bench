## Gate for wp2-t7-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 5 passed in 1.93s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 282:+import asyncpg  # type: ignore[import-untyped]
    added: 297:+pytestmark = pytest.mark.skipif(
    added: 589:+        assert exc_info.value.data["code"] == "not_a_work_item"  # type: ignore[index]
RESULT: FAIL
