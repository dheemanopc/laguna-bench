## Gate for wp1-t3-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/workflow_moves.py:20:5: F401 [*] `mem_mcp.mindmap.workflow_errors.ReasonRequiredError` imported but unused
       |
    18 | from mem_mcp.mindmap import service, work_items
    19 | from mem_mcp.mindmap.workflow_errors import (
    20 |     ReasonRequiredError,
       |     ^^^^^^^^^^^^^^^^^^^ F401
    21 |     SignoffAlreadySignedError,
    22 |     SignoffNotAllowedError,
       |
       = help: Remove unused import: `mem_mcp.mindmap.workflow_errors.ReasonRequiredError`
    
    tests/unit/mindmap/test_workflow_moves.py:10:1: I001 [*] Import block is un-sorted or un-formatted
       |
     9 |   async def test_imports() -> None:
    10 | /     from mem_mcp.mindmap import workflow_moves, work_items
    11 | | 
       | |_^ I001
    12 |       assert workflow_moves.propose_move is not None
    13 |       assert work_items.move_work_item is not None
       |
- mypy (this task's files): clean
- tests: 1 passed in 0.96s
RESULT: FAIL
