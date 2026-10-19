## Gate for wp1-t4-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_reads.py:2:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """DB-backed tests for workflow_reads."""
     2 | / from __future__ import annotations
     3 | | 
     4 | | from uuid import uuid4
     5 | | 
     6 | | import pytest
     7 | | 
     8 | | from mem_mcp.mindmap import workflow_reads, workflow_crud
     9 | | 
    10 | | pytestmark = pytest.mark.asyncio
       | |_^ I001
    11 |   
    12 |   @pytest.fixture
       |
       = help: Organize imports
    
    tests/unit/mindmap/test_workflow_reads.py:37:13: F841 Local variable `root` is assigned to but never used
       |
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/workflow_reads.py:47: error: Returning Any from function declared to return "UUID"  [no-any-return]
    src/mem_mcp/mindmap/workflow_reads.py:137: error: Incompatible types in assignment (expression has type "None", variable has type "str")  [assignment]
- tests: FAIL — 3 passed, 5 errors in 1.81s
    E   asyncpg.exceptions.CheckViolationError: new row for relation "memories" violates check constraint "memories_content_length_check"
    asyncpg/protocol/protocol.pyx:206: CheckViolationError
    E   asyncpg.exceptions.CheckViolationError: new row for relation "memories" violates check constraint "memories_content_length_check"
    asyncpg/protocol/protocol.pyx:206: CheckViolationError
    E   asyncpg.exceptions.CheckViolationError: new row for relation "memories" violates check constraint "memories_content_length_check"
    asyncpg/protocol/protocol.pyx:206: CheckViolationError
    E   asyncpg.exceptions.CheckViolationError: new row for relation "memories" violates check constraint "memories_content_length_check"
    asyncpg/protocol/protocol.pyx:206: CheckViolationError
    E   asyncpg.exceptions.CheckViolationError: new row for relation "memories" violates check constraint "memories_content_length_check"
    asyncpg/protocol/protocol.pyx:206: CheckViolationError
    ERROR tests/unit/mindmap/test_workflow_reads.py::test_compute_item_moves_legacy
    ERROR tests/unit/mindmap/test_workflow_reads.py::test_list_pending_signoffs_excludes_owner_proposer
    ERROR tests/unit/mindmap/test_workflow_reads.py::test_compute_item_moves_blocked_reasons
    ERROR tests/unit/mindmap/test_workflow_reads.py::test_list_pending_signoffs_for_user_respects_roles
    ERROR tests/unit/mindmap/test_workflow_reads.py::test_compute_item_moves_eligible_reflects_owner_exclusion
RESULT: FAIL
