## Gate for wp1-t3-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — 1 failed in 1.10s
            with pytest.raises(TransitionNotFoundError):
            Raises WorkItemMapNotFoundError if map doesn't exist or caller has no role on team.
    >           raise WorkItemMapNotFoundError()
    E           mem_mcp.mindmap.work_items.WorkItemMapNotFoundError: map not found or access denied
    src/mem_mcp/mindmap/work_items.py:300: WorkItemMapNotFoundError
    FAILED tests/unit/mindmap/test_workflow_moves.py::test_propose_move_bad_transition_raises
RESULT: FAIL
