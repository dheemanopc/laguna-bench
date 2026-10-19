## Gate for wp1-t4-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_reads.py:11:1: I001 [*] Import block is un-sorted or un-formatted
       |
     9 |   """
    10 |   
    11 | / from __future__ import annotations
    12 | | 
    13 | | from typing import Any
    14 | | from uuid import UUID, uuid4
    15 | | 
    16 | | import pytest
    17 | | 
    18 | | from mem_mcp.db import tenant_tx
    19 | | from mem_mcp.mindmap import work_items, workflow_reads
    20 | | from mem_mcp.mindmap.workflow_crud import (
    21 | |     StageSpec,
    22 | |     TransitionSpec,
    23 | |     create_team_workflow,
    24 | | )
    25 | | from mem_mcp.mindmap.workflow_moves import propose_move, sign_workflow_move
    26 | | from mem_mcp.teams.assignments import assign_role
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/workflow_reads.py:193: error: Unsupported right operand type for in ("list[str] | None")  [operator]
- tests: FAIL — 1 error in 1.30s
    ImportError while importing test module '~/laguna-bench/runs/BF-4/repo/tests/unit/mindmap/test_workflow_reads.py'.
        from mem_mcp.mindmap.workflow_errors import WorkItemMapNotFoundError
    E   ImportError: cannot import name 'WorkItemMapNotFoundError' from 'mem_mcp.mindmap.workflow_errors' (~/laguna-bench/runs/BF-4/repo/src/mem_mcp/mindmap/workflow_errors.py)
    ERROR tests/unit/mindmap/test_workflow_reads.py
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 1059:+        assert req is not None  # type: ignore[arg-type]
RESULT: FAIL
