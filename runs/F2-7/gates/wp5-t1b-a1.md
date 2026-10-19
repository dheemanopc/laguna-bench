## Gate for wp5-t1b-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_signoff.py:27:5: F401 [*] `mem_mcp.mindmap.workflow_errors.MoveBlockedError` imported but unused
       |
    25 | )
    26 | from mem_mcp.mindmap.workflow_errors import (
    27 |     MoveBlockedError,
       |     ^^^^^^^^^^^^^^^^ F401
    28 |     ReasonRequiredError,
    29 |     SignoffRequiredError,
       |
       = help: Remove unused import
    
    tests/unit/mindmap/test_workflow_signoff.py:29:5: F401 [*] `mem_mcp.mindmap.workflow_errors.SignoffRequiredError` imported but unused
       |
    27 |     MoveBlockedError,
    28 |     ReasonRequiredError,
    29 |     SignoffRequiredError,
       |     ^^^^^^^^^^^^^^^^^^^^ F401
    30 | )
    31 | from mem_mcp.mindmap.workflow_moves import (
       |
- mypy (this task's files): clean
- tests: 15 passed in 3.69s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 42:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
