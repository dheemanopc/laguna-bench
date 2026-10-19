## Gate for wp2-t7-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_work_list_get_e2e.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """End-to-end integration tests for mindmap_work_list / mindmap_work_get."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | import os
     6 | | from uuid import uuid4
     7 | | 
     8 | | import asyncpg
     9 | | import pytest
    10 | | 
    11 | | from mem_mcp.mcp.errors import JsonRpcError
    12 | | from mem_mcp.mcp.tools._base import ToolContext
    13 | | from mem_mcp.mcp.tools._deps import NoopQuotas, ToolDeps
    14 | | from mem_mcp.mcp.tools.mindmap_work_get import MindmapWorkGetInput, MindmapWorkGetTool
    15 | | from mem_mcp.mcp.tools.mindmap_work_list import MindmapWorkListInput, MindmapWorkListTool
    16 | | from mem_mcp.mcp.tools.mindmap_work_mark import MindmapWorkMarkInput, MindmapWorkMarkTool
    17 | | from mem_mcp.audit.logger import NoopAuditLogger
    18 | | 
- mypy (this task's files): clean
- tests: 5 passed in 1.65s
RESULT: FAIL
