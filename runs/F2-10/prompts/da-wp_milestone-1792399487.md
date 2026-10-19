EVENT wp_milestone. Package WP1 is built (tasks: WP1-T1, WP1-T2, WP1-T3, WP1-T4). Milestone gate output:
## Milestone gate wp1 (harness-run)
- ruff: [*] 4 fixable with the `--fix` option.
- mypy: Success: no issues found in 187 source files
- alembic heads: 1
- full suite:  1 error in 4.78s
- NEW failures vs known red: 1
    tests/unit/mindmap/test_workflow_errors.py
- web: no changes
RESULT: FAIL

Spawn ONE Agent subagent to review the package's code against `docs/feature/wp1.md` and 00-goal.md (brief: "Review
the changes for WP1 in ~/laguna-bench/runs/F2-10/repo: `git diff 5406436abfdd798a3743e353ef3b97a35e204d0d -- src/mem_mcp/mindmap/work_items.py src/mem_mcp/mindmap/workflow_crud.py src/mem_mcp/mindmap/workflow_errors.py src/mem_mcp/mindmap/workflow_moves.py src/mem_mcp/mindmap/workflow_reads.py tests/unit/mindmap/test_workflow_crud.py tests/unit/mindmap/test_workflow_errors.py tests/unit/mindmap/test_workflow_moves.py tests/unit/mindmap/test_workflow_reads.py` plus new files. Check correctness against the plan, the
interfaces promised to later packages, tenant/visibility rules, weakened checks, missing tests. Return at most 5
one-line findings with file:line, most important first, or 'none'."). Then decide which findings must be fixed now.
Reply json: {"verdict":"APPROVE|REVISE","findings":["<=5 findings that must be fixed, each self-contained for an engineer"]}