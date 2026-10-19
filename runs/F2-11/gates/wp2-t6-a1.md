## Gate for wp2-t6-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflow_signoff_remap_e2e.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """End-to-end integration tests for signoff/cancel/remap tools (smoke)."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | from mem_mcp.mcp.tools.mindmap_workflow_signoff import MindmapWorkflowSignoffTool
     6 | | from mem_mcp.mcp.tools.mindmap_workflow_cancel_move import MindmapWorkflowCancelMoveTool
     7 | | from mem_mcp.mcp.tools.mindmap_workflow_remap import MindmapWorkflowRemapTool
     8 | | 
     9 | | 
    10 | | def test_imports() -> None:
       | |_^ I001
    11 |       assert MindmapWorkflowSignoffTool.name == "mindmap_workflow_signoff"
    12 |       assert MindmapWorkflowCancelMoveTool.name == "mindmap_workflow_cancel_move"
       |
       = help: Organize imports
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 1 passed in 1.03s
RESULT: FAIL
