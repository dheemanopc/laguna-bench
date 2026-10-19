## Gate for wp1-t3-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/work_items.py:12:1: I001 [*] Import block is un-sorted or un-formatted
       |
    10 |   """
    11 |   
    12 | / from __future__ import annotations
    13 | | 
    14 | | from dataclasses import dataclass
    15 | | from datetime import datetime
    16 | | from typing import Any, Literal
    17 | | from uuid import UUID
    18 | | 
    19 | | import asyncpg  # type: ignore[import-untyped]
    20 | | 
    21 | | from mem_mcp.auth.permissions import ROLE_PERMISSIONS, Permission
    22 | | from mem_mcp.auth.rbac import get_team_role
    23 | | from mem_mcp.mindmap import service
    24 | | from mem_mcp.mindmap import workflow_errors
    25 | | 
    26 | | # -------------------------------------------------------------------------
       | |_^ I001
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/work_items.py:295: error: Returning Any from function declared to return "str"  [no-any-return]
    src/mem_mcp/mindmap/work_items.py:296: error: Returning Any from function declared to return "str"  [no-any-return]
    src/mem_mcp/mindmap/work_items.py:589: error: Argument "channel" to "propose_move" has incompatible type "str"; expected "Literal['mcp', 'web']"  [arg-type]
    src/mem_mcp/mindmap/workflow_moves.py:232: error: Any? not callable  [misc]
- tests: 43 passed in 4.65s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 69:+        return active_id  # type: ignore[no-any-return]
    added: 246:+import asyncpg  # type: ignore[import-untyped]
    added: 2924:+        import mem_mcp.mindmap.workflow_moves  # noqa: F401
    added: 2925:+        import mem_mcp.mindmap.work_items  # noqa: F401
RESULT: FAIL
