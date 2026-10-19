EVENT wp_milestone. Package WP5 is built (tasks: WP5-T1a, WP5-T1b, WP5-T2a, WP5-T2b). Milestone gate output:
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

Spawn ONE Agent subagent to review the package's code against `docs/feature/wp5.md` and 00-goal.md (brief: "Review
the changes for WP5 in ~/laguna-bench/runs/F2-7/repo: `git diff 5406436abfdd798a3743e353ef3b97a35e204d0d -- tests/integration/test_mindmap_workflow_web_e2e.py tests/integration/test_mindmap_workflows_e2e.py tests/unit/mindmap/test_workflow.py tests/unit/mindmap/test_workflow_signoff.py` plus new files. Check correctness against the plan, the
interfaces promised to later packages, tenant/visibility rules, weakened checks, missing tests. Return at most 5
one-line findings with file:line, most important first, or 'none'."). Then decide which findings must be fixed now.
Reply json: {"verdict":"APPROVE|REVISE","findings":["<=5 findings that must be fixed, each self-contained for an engineer"]}