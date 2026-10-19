## Gate for wp3-t1-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/web/handlers/workflows.py:8:1: I001 [*] Import block is un-sorted or un-formatted
       |
     6 |   """
     7 |   
     8 | / from __future__ import annotations
     9 | | 
    10 | | from typing import Any
    11 | | from uuid import UUID, uuid4
    12 | | 
    13 | | import asyncpg  # type: ignore[import-untyped]
    14 | | from fastapi import APIRouter, Cookie, HTTPException
    15 | | from pydantic import BaseModel, Field
    16 | | 
    17 | | from mem_mcp.mcp.errors import JsonRpcError
    18 | | from mem_mcp.mcp.tools._base import ToolContext
    19 | | from mem_mcp.mcp.tools._deps import ToolDeps
    20 | | from mem_mcp.mcp.tools.mindmap_workflow_activate import (
    21 | |     MindmapWorkflowActivateInput,
    22 | |     MindmapWorkflowActivateTool,
    23 | | )
- mypy (this task's files): clean
- tests: 6 passed, 1 warning in 1.39s
RESULT: FAIL
