## Gate for wp1-t3-a2 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_moves.py:2:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Tests for workflow_moves (WP1-T3)."""
     2 | / import pytest
     3 | | from uuid import uuid4
     4 | | from mem_mcp.mindmap.workflow_moves import propose_move, sign_workflow_move, cancel_workflow_move
     5 | | from mem_mcp.mindmap.workflow_errors import TransitionNotFoundError, ReasonRequiredError, SignoffNotAllowedError
     6 | | 
     7 | | 
     8 | | @pytest.mark.asyncio
       | |_^ I001
     9 |   async def test_propose_move_bad_transition_raises(db_session):
    10 |       # Bad transition should raise
       |
       = help: Organize imports
    
    tests/unit/mindmap/test_workflow_moves.py:4:58: F401 [*] `mem_mcp.mindmap.workflow_moves.sign_workflow_move` imported but unused
      |
    2 | import pytest
    3 | from uuid import uuid4
- mypy (this task's files): clean
- tests: FAIL — 1 failed in 1.14s
            with pytest.raises(TransitionNotFoundError):
            Raises WorkItemMapNotFoundError if map doesn't exist or caller has no role on team.
    >           raise WorkItemMapNotFoundError()
    E           mem_mcp.mindmap.work_items.WorkItemMapNotFoundError: map not found or access denied
    src/mem_mcp/mindmap/work_items.py:295: WorkItemMapNotFoundError
    FAILED tests/unit/mindmap/test_workflow_moves.py::test_propose_move_bad_transition_raises
RESULT: FAIL
