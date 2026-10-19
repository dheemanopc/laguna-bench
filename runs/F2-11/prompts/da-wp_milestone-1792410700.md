EVENT wp_milestone. Package WP3 is built (tasks: WP3-T1, WP3-T2). Milestone gate output:
## Milestone gate wp3 (harness-run)
- ruff: All checks passed!
- mypy: Success: no issues found in 200 source files
- alembic heads: 1
- full suite:  18 failed, 1477 passed, 31 skipped, 98 warnings, 16 errors in 41.69s
- NEW failures vs known red: 0
- web: no changes
RESULT: PASS

Spawn ONE Agent subagent to review the package's code against `docs/feature/wp3.md` and 00-goal.md (brief: "Review
the changes for WP3 in ~/laguna-bench/runs/F2-11/repo: `git diff 5406436abfdd798a3743e353ef3b97a35e204d0d -- src/mem_mcp/main.py src/mem_mcp/web/handlers/mindmaps.py src/mem_mcp/web/handlers/workflows.py tests/unit/test_web_mindmaps_work_items_router.py tests/unit/test_web_workflows_router.py` plus new files. Check correctness against the plan, the
interfaces promised to later packages, tenant/visibility rules, weakened checks, missing tests. Return at most 5
one-line findings with file:line, most important first, or 'none'."). Then decide which findings must be fixed now.
Reply json: {"verdict":"APPROVE|REVISE","findings":["<=5 findings that must be fixed, each self-contained for an engineer"]}