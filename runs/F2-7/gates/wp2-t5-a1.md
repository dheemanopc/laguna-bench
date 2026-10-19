## Gate for wp2-t5-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """mindmap_workflow_propose_move — propose moving a work item through workflow stages."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | from typing import ClassVar
     6 | | from uuid import UUID
     7 | | 
     8 | | from pydantic import BaseModel, Field
     9 | | 
    10 | | from mem_mcp.db import tenant_tx
    11 | | from mem_mcp.mcp.tool_descriptions import TOOL_DESCRIPTIONS
    12 | | from mem_mcp.mcp.tools._base import BaseTool, ToolContext
    13 | | from mem_mcp.mcp.tools._mindmap_common import resolve_team_id
    14 | | from mem_mcp.mcp.tools._work_item_common import (
    15 | |     ProposeMoveOutput,
    16 | |     map_work_item_error,
    17 | | )
    18 | | from mem_mcp.mindmap import work_items as work_item_service
- mypy (this task's files): FAIL
    src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:87: error: "WorkItem" has no attribute "current_stage"  [attr-defined]
- tests: 1 passed in 1.06s
RESULT: FAIL
