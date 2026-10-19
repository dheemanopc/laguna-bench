## Gate for wp5-t1b-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_signoff.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Tests for workflow_moves (propose/sign/cancel) + workflow_reads + error types."""
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
    12 | | from mem_mcp.db import tenant_tx
    13 | | from mem_mcp.mindmap import work_items, workflow_moves, workflow_reads
    14 | | from mem_mcp.mindmap.workflow_crud import create_team_workflow, activate_workflow, materialise_legacy_workflow
    15 | | from mem_mcp.mindmap.workflow_errors import (
    16 | |     MoveBlockedError,
    17 | |     ReasonRequiredError,
    18 | |     SignoffNotAllowedError,
- mypy (this task's files): clean
- tests: 11 passed in 2.25s
RESULT: FAIL
