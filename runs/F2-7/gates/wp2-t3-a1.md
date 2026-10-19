## Gate for wp2-t3-a1 (harness-run)
- ruff: FAIL
    tests/unit/test_workflow_tool_descriptions.py:3:1: I001 [*] Import block is un-sorted or un-formatted
      |
    1 |   """Test that workflow tool descriptions are present, well-formed, and follow the required structure."""
    2 |   
    3 | / import re
    4 | | from mem_mcp.mcp.tool_descriptions import TOOL_DESCRIPTIONS
    5 | | 
    6 | | 
    7 | | REQUIRED_WORKFLOW_TOOLS = [
      | |_^ I001
    8 |       "mindmap_workflow_create",
    9 |       "mindmap_workflow_get",
      |
      = help: Organize imports
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 6 passed in 0.96s
RESULT: FAIL
