## Gate for wp5-t2b-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflow_web_e2e.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Web-path parity e2e for mindmap workflows (WP5-T2b)."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | import os
     6 | | import uuid
     7 | | from datetime import UTC, datetime, timedelta
     8 | | from typing import Any
     9 | | from uuid import UUID, uuid4
    10 | | 
    11 | | import pytest
    12 | | 
    13 | | from fastapi.testclient import TestClient
    14 | | 
    15 | | 
    16 | | def _cookies(raw: str) -> dict[str, str]:
       | |_^ I001
    17 |       return {"mem_session": raw}
- mypy (this task's files): clean
- tests: 2 passed, 14 warnings in 2.88s
RESULT: FAIL
