## Gate for wp1-g1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — 1 failed, 28 passed in 2.06s
            # Only work_items (for ReasonRequiredError) and this module should appear
    >           assert n in allowed or n.startswith("mem_mcp.mindmap.workflow_errors") or "test_workflow_errors" in n, f"unexpected module: {n}"
    E           AssertionError: unexpected module: mem_mcp.mindmap.workflow_moves
    E           assert ('mem_mcp.mindmap.workflow_moves' in {'mem_mcp.mindmap.work_items', 'mem_mcp.mindmap.workflow_errors', 'tests.unit.mindmap.test_workflow_errors'} or False or 'test_workflow_errors' in 'mem_mcp.mindmap.workflow_moves')
    tests/unit/mindmap/test_workflow_errors.py:65: AssertionError
    FAILED tests/unit/mindmap/test_workflow_errors.py::test_no_cycle_imports - As...
RESULT: FAIL
