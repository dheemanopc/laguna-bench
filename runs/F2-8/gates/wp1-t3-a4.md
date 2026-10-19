## Gate for wp1-t3-a4 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_moves.py:2:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Tests for workflow_moves (WP1-T3)."""
     2 | / from uuid import UUID, uuid4
     3 | | 
     4 | | import asyncpg
     5 | | import pytest
     6 | | 
     7 | | from mem_mcp.mindmap.workflow_errors import ReasonRequiredError, TransitionNotFoundError
     8 | | from mem_mcp.mindmap.workflow_moves import propose_move, WorkflowSignoffRequest
     9 | | from mem_mcp.mindmap import workflow_crud
    10 | | from mem_mcp.mindmap.work_items import mark_work_item, WorkItem
    11 | | from mem_mcp.teams.assignments import assign_role
    12 | | 
    13 | | pytestmark = pytest.mark.asyncio
       | |_^ I001
    14 |   
    15 |   @pytest.fixture
       |
       = help: Organize imports
- mypy (this task's files): clean
- tests: FAIL — 1 failed, 2 passed in 1.46s
                    with pytest.raises(TransitionNotFoundError):
    E   asyncpg.exceptions.IndeterminateDatatypeError: could not determine data type of parameter $2
    asyncpg/protocol/protocol.pyx:165: IndeterminateDatatypeError
    FAILED tests/unit/mindmap/test_workflow_moves.py::test_propose_move_bad_transition_raises
RESULT: FAIL
