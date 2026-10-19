## Gate for wp4-t5-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:19:8: F401 [*] `json` imported but unused
       |
    18 | import hashlib
    19 | import json
       |        ^^^^ F401
    20 | import os
    21 | import secrets
       |
       = help: Remove unused import: `json`
    
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:521:5: F841 Local variable `tenant_a` is assigned to but never used
        |
    519 |             session_id = await _create_session(conn, data["tenant_a"], data["identity_a"])
    520 | 
    521 |     tenant_a = data["tenant_a"]
        |     ^^^^^^^^ F841
    522 |     tenant_b = data["tenant_b"]
    523 |     team = data["team"]
        |
        = help: Remove assignment to unused variable `tenant_a`
- mypy (this task's files): clean
- tests: 3 passed, 3 warnings in 3.38s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 26:+import asyncpg  # type: ignore[import-untyped]
    added: 31:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
