## Gate for wp1-t3-a1 (harness-run)
- note: planned files not present: tests/unit/mindmap/test_workflow_moves.py
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/work_items.py:463: error: Unused "type: ignore" comment  [unused-ignore]
    src/mem_mcp/mindmap/work_items.py:463: error: Returning Any from function declared to return "UUID"  [no-any-return]
    src/mem_mcp/mindmap/work_items.py:463: note: Error code "no-any-return" not covered by "type: ignore" comment
- tests: FAIL — none of the planned test files exist (tests/unit/mindmap/test_workflow_moves.py)
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 22:+        return row["workflow_id"]  # type: ignore[return-value]
RESULT: FAIL
