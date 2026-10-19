## Gate for wp1-t1-a2 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_errors.py:3:17: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
      |
    1 | '''Tests for the workflow error hierarchy defined in src/mem_mcp/mindmap/workflow_errors.py.
    2 | 
    3 | All tests are DB‑free – they only instantiate the exception classes and verify
      |                 ^ RUF002
    4 | behaviour such as inheritance, stored attributes and string representations.
    5 | '''
      |
    
    tests/unit/mindmap/test_workflow_errors.py:3:23: RUF002 Docstring contains ambiguous `–` (EN DASH). Did you mean `-` (HYPHEN-MINUS)?
      |
    1 | '''Tests for the workflow error hierarchy defined in src/mem_mcp/mindmap/workflow_errors.py.
    2 | 
    3 | All tests are DB‑free – they only instantiate the exception classes and verify
      |                       ^ RUF002
    4 | behaviour such as inheritance, stored attributes and string representations.
    5 | '''
      |
    
- mypy (this task's files): clean
- tests: 13 passed in 1.03s
RESULT: FAIL
