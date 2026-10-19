## Gate for wp2-t4-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflow_crud_e2e.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Integration tests for workflow CRUD tools (create, get, activate)."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | import os
     6 | | from typing import Any
     7 | | from uuid import UUID, uuid4
     8 | | 
     9 | | import asyncpg
    10 | | import pytest
    11 | | 
    12 | | from mem_mcp.mcp.errors import JsonRpcError
    13 | | from mem_mcp.mcp.tools._base import ToolContext
    14 | | from mem_mcp.mcp.tools.mindmap_workflow_activate import MindmapWorkflowActivateTool, MindmapWorkflowActivateInput
    15 | | from mem_mcp.mcp.tools.mindmap_workflow_create import MindmapWorkflowCreateTool, MindmapWorkflowCreateInput
    16 | | from mem_mcp.mcp.tools.mindmap_workflow_get import MindmapWorkflowGetTool, MindmapWorkflowGetInput
    17 | | from mem_mcp.mcp.tools._work_item_common import WorkflowDetailOutput
    18 | | 
- mypy (this task's files): FAIL
    src/mem_mcp/mcp/tools/mindmap_workflow_create.py:8: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
    src/mem_mcp/mcp/tools/mindmap_workflow_create.py:8: note: See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports
- tests: 9 passed in 1.92s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 385:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
