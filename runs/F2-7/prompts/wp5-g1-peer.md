You are reviewing a teammate's finished task. Do NOT edit any file. Task WP5-G1: fix WP5 gate failures
Acceptance: #1 The package milestone gate failed (full suite / mypy / ruff / web). Fix these:
## Milestone gate wp5 (harness-run)
- ruff: All checks passed!
- mypy: Success: no issues found in 199 source files
- alembic heads: 1
- full suite:  24 failed, 1589 passed, 31 skipped, 144 warnings, 16 errors in 61.42s (0:01:01)
- NEW failures vs known red: 6
    tests/unit/test_web_mindmaps_work_items_router.py::test_not_eligible_error_returns_400
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_complete_returns_400
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_request_must_belong_to_specified_map
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_request_must_belong_to_specified_node
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_request_not_found
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_work_item_delegates_to_tool
- web tsc: 0 errors
- web build:  ✓ Compiled successfully in 4.7s 
RESULT: FAIL

Package plan: `docs/feature/wp5.md` (DESIGN section). Changed files: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
