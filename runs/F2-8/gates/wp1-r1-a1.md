## Gate for wp1-r1-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/work_items.py:28:5: F401 [*] `mem_mcp.mindmap.workflow_errors.MoveBlockedError` imported but unused
       |
    26 | from mem_mcp.mindmap import service
    27 | from mem_mcp.mindmap.workflow_errors import (
    28 |     MoveBlockedError,
       |     ^^^^^^^^^^^^^^^^ F401
    29 |     ReasonRequiredError,
    30 |     StageConflictError,
       |
       = help: Remove unused import: `mem_mcp.mindmap.workflow_errors.MoveBlockedError`
    
    src/mem_mcp/mindmap/work_items.py:817:9: F841 Local variable `current_stage` is assigned to but never used
        |
    815 |     # Route through workflow when item has a workflow
    816 |     if wi_row.get("workflow_id") is not None:
    817 |         current_stage = wi_row.get("current_stage") or wi_row["status"]
        |         ^^^^^^^^^^^^^ F841
    818 |         # Kind change does not advance stage; just validate workflow allows staying
    819 |         # at current stage (no transition needed) — only block if stage would change
        |
- mypy (this task's files): clean
- tests: 29 passed in 2.26s
RESULT: FAIL
