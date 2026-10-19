## Gate for wp3-t2-a1 (harness-run)
- ruff: FAIL
    tests/unit/test_web_mindmaps_work_items_router.py:45:5: F841 Local variable `bodies` is assigned to but never used
       |
    43 | def test_every_endpoint_requires_a_session(method: str, path: str) -> None:
    44 |     client = _client()
    45 |     bodies = {
       |     ^^^^^^ F841
    46 |         f"/api/web/mindmaps/m/work-items/{path.split('/')[-2] if 'move' in path or 'signoff' in path else 'x'}/move": {
    47 |             "to_stage": "done",
       |
       = help: Remove assignment to unused variable `bodies`
    
    Found 1 error.
    No fixes available (1 hidden fix can be enabled with the `--unsafe-fixes` option).
- mypy (this task's files): clean
- tests: 21 passed, 11 warnings in 2.47s
RESULT: FAIL
