EVENT wp_milestone. Package WP4 is built (tasks: WP4-T1, WP4-T2, WP4-T3, WP4-T4a, WP4-T4b, WP4-T5). Milestone gate output:
## Milestone gate wp4 (harness-run)
- ruff: All checks passed!
- mypy: Success: no issues found in 199 source files
- alembic heads: 1
- full suite:  18 failed, 1556 passed, 31 skipped, 132 warnings, 16 errors in 50.40s
- NEW failures vs known red: 0
- web tsc: 0 errors
- web build:  ✓ Compiled successfully in 15.6s 
RESULT: PASS

Spawn ONE Agent subagent to review the package's code against `docs/feature/wp4.md` and 00-goal.md (brief: "Review
the changes for WP4 in ~/laguna-bench/runs/F2-7/repo: `git diff 5406436abfdd798a3743e353ef3b97a35e204d0d -- tests/integration/test_mindmap_workflow_web_ui_shapes.py web/app/mindmaps/[key]/board/BoardContext.tsx web/app/mindmaps/[key]/board/BoardView.tsx web/app/mindmaps/[key]/board/ItemDetail.tsx web/app/mindmaps/[key]/board/WaitingOnYou.tsx web/app/mindmaps/[key]/board/page.tsx web/app/teams/[team_id]/workflow/WorkflowEditor.tsx web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx web/app/teams/[team_id]/workflow/page.tsx` plus new files. Check correctness against the plan, the
interfaces promised to later packages, tenant/visibility rules, weakened checks, missing tests. Return at most 5
one-line findings with file:line, most important first, or 'none'."). Then decide which findings must be fixed now.
Reply json: {"verdict":"APPROVE|REVISE","findings":["<=5 findings that must be fixed, each self-contained for an engineer"]}