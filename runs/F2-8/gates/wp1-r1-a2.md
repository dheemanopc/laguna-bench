## Gate for wp1-r1-a2 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_errors.py:58:1: I001 [*] Import block is un-sorted or un-formatted
       |
    57 |   def test_no_cycle_imports():
    58 | /     import subprocess
    59 | |     import sys
    60 | |     import tempfile
    61 | |     import os
    62 | |     with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
       | |_^ I001
    63 |           f.write("import sys, mem_mcp.mindmap.workflow_errors\n")
    64 |           f.write("forbad = ['mem_mcp.mindmap.work_items', 'mem_mcp.mindmap.workflow_moves', 'mem_mcp.mindmap.workflow_crud', 'mem_mcp.mindmap.workflow_reads']\n")
       |
       = help: Organize imports
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 29 passed in 2.47s
RESULT: FAIL
