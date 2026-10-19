You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-G1: fix WP1 gate failures
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
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

Read first: see plan
Already finished tasks you build on: none

RETRY (attempt 3): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp1-g1-a2 (harness-run)
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/mindmap/workflow_crud.py:17: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
    src/mem_mcp/mindmap/workflow_crud.py:17: note: See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports
- tests: 46 passed in 3.11s
RESULT: FAIL

Previous attempt's final message:
, tests/unit/mindmap/test_workflow_moves.py

TESTS: 
- `pytest tests/unit/mindmap/test_workflow_crud.py tests/unit/mindmap/test_workflow_errors.py tests/unit/mindmap/test_workflow_moves.py tests/unit/mindmap/test_workflow_reads.py -q` -> 46 passed in 3.50s
- `ruff check src tests` -> All checks passed!
- `alembic upgrade head` -> (no changes needed)

CHECKLIST: none

NOTES: The previous attempt added type: ignore comments to test files as a workaround for asyncpg's missing stubs, but the harness flagged these as "weakened checks" and requested their removal. Fixed by: (1) Removing the newly-added type: ignore[import-untyped] from test file imports; (2) Restoring the original workflow_crud.py structure with TYPE_CHECKING import; (3) Adding cast(UUID, ...) to fix a return type annotation in test_workflow_crud.py. The original source files (work_items.py, workflow_moves.py) retained their pre-existing type: ignore comments as these follow the established codebase convention and are not newly-added weakening. Remaining mypy errors about asyncpg stubs are pre-existing issues that cannot be resolved without either weakening checks or modifying configuration (both forbidden by the rules).
Fix the failures (CHECKLIST each gate failure).
Environment (already set up, do not inspect it): the test database DSN is preset in your environment, so just run
`pytest <files> -q` (and `alembic upgrade head` for migrations). Never run env/printenv or read env vars. If the guard
blocks a command, do NOT retry it or a variant: use another approach or record it under NOTES.
Think briefly, then act: write the code early and let the tests tell you what is wrong.

Write the code and its tests, run the tests, fix what fails, then end with the response format.

## Rules (always apply)
DO
- Work ONLY on the files listed for your task. If you truly must touch another file, keep the change minimal and name it
  under NOTES with the reason.
- Find code with Grep first, then Read only the parts you need (use offset/limit). Your session has a hard budget of
  about 100k tokens of context; it is stopped beyond that, so do not read whole large files or dump big outputs.
- Run the tests named in your task (`pytest <files> -q`). If you changed or added a migration, run `alembic upgrade head`
  first. The harness re-runs every check itself; your claims are not trusted, so report results verbatim.
- If something is ambiguous, decide, follow the existing code's conventions, and record the assumption under NOTES.
- Web docs are allowed when you need them (GET only): `curl -sL <url>` or WebFetch, on pypi.org, docs.python.org,
  fastapi.tiangolo.com, docs.sqlalchemy.org, alembic.sqlalchemy.org, magicstack.github.io (asyncpg), www.postgresql.org,
  nextjs.org, react.dev, www.typescriptlang.org, playwright.dev, www.npmjs.com, raw.githubusercontent.com, github.com.
DON'T
- Never weaken a check to get green: no `# noqa`, no `type: ignore`, no `pytest.mark.skip/xfail`, no edits to lint or
  type-check config (pyproject tool sections, tools/lint_*.py, tsconfig, eslint), no deleting or loosening existing tests.
  If an existing test conflicts with the planned behaviour, say so under NOTES instead.
- Don't ask questions or wait for answers: nobody replies mid-task.
- Don't redirect output into files outside the repo; create files with the Write tool; run commands plainly.
- Don't send data anywhere (no POST/upload); never read or print credentials or .env files.
- Don't start other work beyond your task.

## Response format (your FINAL message, exactly these headings, nothing else)
RESULT: DONE | BLOCKED
CHANGED: <comma-separated repo paths you created or modified>
TESTS: <each command you ran> -> <its last summary line, verbatim>
CHECKLIST: <only when fixing findings: one line per finding "#<n> FIXED <where>" or "#<n> NOT FIXED <why>">
NOTES: <at most 5 short lines: assumptions, deviations, follow-ups; "none" if none>

