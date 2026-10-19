## Gate for wp1-t4-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_reads.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Tests for workflow_reads (compute_item_moves + list_pending_signoffs_for_user)."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | from uuid import uuid4
     6 | | 
     7 | | import asyncpg
     8 | | import pytest
     9 | | 
    10 | | from mem_mcp.db import tenant_tx
    11 | | from mem_mcp.mindmap import workflow_crud, workflow_reads, work_items
    12 | | from mem_mcp.mindmap.workflow_errors import WorkflowPermissionDeniedError
    13 | | from mem_mcp.teams.assignments import assign_role
    14 | | 
    15 | | pytestmark = pytest.mark.asyncio
       | |_^ I001
       |
       = help: Organize imports
- mypy (this task's files): clean
- tests: 4 passed in 1.18s
RESULT: FAIL
