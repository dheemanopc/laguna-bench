## Gate for wp3-t1-a2 (harness-run)
- ruff: FAIL
    tests/unit/test_web_workflows_router.py:52:5: F841 Local variable `out` is assigned to but never used
       |
    50 | def test_code_surfaces() -> None:
    51 |     client = _client()
    52 |     out = None
       |     ^^^ F841
    53 | 
    54 |     async def fake_call(ctx: Any, inp: Any) -> Any:
       |
       = help: Remove assignment to unused variable `out`
    
    Found 1 error.
    No fixes available (1 hidden fix can be enabled with the `--unsafe-fixes` option).
- mypy (this task's files): clean
- tests: 6 passed, 1 warning in 1.39s
RESULT: FAIL
