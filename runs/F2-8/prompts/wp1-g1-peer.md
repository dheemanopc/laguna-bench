You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-G1: fix WP1 gate failures
Acceptance: #1 The package milestone gate failed (full suite / mypy / ruff / web). Fix these:
## Milestone gate wp1 (harness-run)
- ruff: [*] 1 fixable with the `--fix` option.
- mypy: Found 17 errors in 3 files (checked 187 source files)
    src/mem_mcp/mcp/tools/_work_item_common.py:14: error: Module "mem_mcp.mindmap.work_items" does not explicitly export attribute "ReasonRequiredError"  [attr-defined]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:82: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "map_state"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:83: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "kind"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:85: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "assignee_id"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:86: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "title"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:87: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "created_by"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:88: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "created_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:89: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "updated_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:90: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "status_changed_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_kind.py:80: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "map_state"  [union-attr]
- alembic heads: 1
- full suite:  23 failed, 1441 passed, 31 skipped, 94 warnings, 16 errors in 45.13s
- NEW failures vs known red: 5
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_blocked_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_cancelled_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_reason_blank_rejected
    tests/unit/mindmap/test_workflow_errors.py::test_no_cycle_imports
    tests/unit/mindmap/test_workflow_moves.py::test_propose_move_bad_transition_raises
- web: no changes
RESULT: FAIL

Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
