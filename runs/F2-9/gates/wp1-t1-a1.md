## Gate for wp1-t1-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/workflow_errors.py:3:64: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
      |
    1 | """Shared workflow exception hierarchy.
    2 | 
    3 | This module defines a set of exception classes used by the mind‑map workflow
      |                                                                ^ RUF002
    4 | service.  The hierarchy mirrors the `work_items` exceptions but is independent
    5 | so that the work‑item and workflow layers can import each other without creating
      |
    
    src/mem_mcp/mindmap/workflow_errors.py:5:17: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
      |
    3 | This module defines a set of exception classes used by the mind‑map workflow
    4 | service.  The hierarchy mirrors the `work_items` exceptions but is independent
    5 | so that the work‑item and workflow layers can import each other without creating
      |                 ^ RUF002
    6 | an import cycle.
      |
    
    src/mem_mcp/mindmap/workflow_errors.py:9:59: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
- mypy (this task's files): clean
- tests: 13 passed in 1.13s
RESULT: FAIL
