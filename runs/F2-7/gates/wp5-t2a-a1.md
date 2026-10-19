## Gate for wp5-t2a-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflows_e2e.py:38:5: F401 [*] `mem_mcp.mcp.tools.mindmap_workflow_pending_signoffs.MindmapWorkflowPendingSignoffsInput` imported but unused
       |
    36 | )
    37 | from mem_mcp.mcp.tools.mindmap_workflow_pending_signoffs import (
    38 |     MindmapWorkflowPendingSignoffsInput,
       |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ F401
    39 |     MindmapWorkflowPendingSignoffsTool,
    40 | )
       |
       = help: Remove unused import
    
    tests/integration/test_mindmap_workflows_e2e.py:39:5: F401 [*] `mem_mcp.mcp.tools.mindmap_workflow_pending_signoffs.MindmapWorkflowPendingSignoffsTool` imported but unused
       |
    37 | from mem_mcp.mcp.tools.mindmap_workflow_pending_signoffs import (
    38 |     MindmapWorkflowPendingSignoffsInput,
    39 |     MindmapWorkflowPendingSignoffsTool,
       |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ F401
    40 | )
    41 | from mem_mcp.mcp.tools.mindmap_workflow_propose_move import (
       |
- mypy (this task's files): clean
- tests: 2 passed in 1.39s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 55:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
