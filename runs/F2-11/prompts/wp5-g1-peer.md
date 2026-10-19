You are reviewing a teammate's finished task. Do NOT edit any file. Task WP5-G1: fix WP5 gate failures
Acceptance: #1 The package milestone gate failed (full suite / mypy / ruff / web). Fix these:
## Milestone gate wp5 (harness-run)
- ruff: All checks passed!
- mypy: Success: no issues found in 200 source files
- alembic heads: 1
- full suite:  19 failed, 1504 passed, 31 skipped, 116 warnings, 16 errors in 46.52s
- NEW failures vs known red: 1
    tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_error_codes
- web tsc: 0 errors
- web build:  ✓ Compiled successfully in 4.6s 
RESULT: FAIL

Package plan: `docs/feature/wp5.md` (DESIGN section). Changed files: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
