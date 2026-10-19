You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-G1: fix WP1 gate failures
Acceptance: #1 The package milestone gate failed (full suite / mypy / ruff / web). Fix these:
## Milestone gate wp1 (harness-run)
- ruff: All checks passed!
- mypy: Found 1 error in 1 file (checked 187 source files)
    src/mem_mcp/mindmap/workflow_crud.py:17: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
    Found 1 error in 1 file (checked 187 source files)
- alembic heads: 1
- full suite:  18 failed, 1463 passed, 31 skipped, 94 warnings, 16 errors in 54.95s
- NEW failures vs known red: 0
- web: no changes
RESULT: FAIL

Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
