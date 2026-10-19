## Gate for wp1-t2-a1 (harness-run)
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/workflow_crud.py:50: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:57: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:58: error: Call to untyped function "_require_write_memory" in typed context  [no-untyped-call]
    src/mem_mcp/mindmap/workflow_crud.py:88: error: Call to untyped function "get_workflow" in typed context  [no-untyped-call]
    src/mem_mcp/mindmap/workflow_crud.py:90: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:91: error: Call to untyped function "_require_write_memory" in typed context  [no-untyped-call]
    src/mem_mcp/mindmap/workflow_crud.py:99: error: Call to untyped function "get_workflow" in typed context  [no-untyped-call]
    src/mem_mcp/mindmap/workflow_crud.py:101: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:116: error: Need type annotation for "transitions"  [var-annotated]
    src/mem_mcp/mindmap/workflow_crud.py:130: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:158: error: Function is missing a type annotation  [no-untyped-def]
    src/mem_mcp/mindmap/workflow_crud.py:159: error: Call to untyped function "_require_write_memory" in typed context  [no-untyped-call]
- tests: 4 passed in 1.22s
RESULT: FAIL
