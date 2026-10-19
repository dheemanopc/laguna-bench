You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-R1: fix WP1 review findings
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Acceptance: #1 tests/unit/test_migration_0048_workflow_schema.py:75 asserts head == '0048_team_workflows', but WP1 added alembic/versions/0049_2026_10_19_signoff_request_workflow_id.py. Fix it without weakening the test's intent: either fold the signoff_request.workflow_id column into 0048 (if 0048 is unreleased) and delete 0049, or change the test to assert that 0048 is an ancestor of head. The new failure must go away. Don't skip the test.; #2 src/mem_mcp/mindmap/work_items.py:~460 mark_work_item still inserts with status='todo' and no workflow_id/current_stage. docs/feature/wp1.md says item creation routes through _resolve_workflow. Items created while the team has an active workflow must get that workflow_id and its initial stage. Add a test that creates an item while a workflow is active.; #3 src/mem_mcp/mindmap/workflow_moves.py:~330 sign_workflow_move: in the stale-stage branch it cancels the request and returns None, which looks the same as 'still pending'. Return or raise something distinct (for example a result status 'voided' or a specific WorkflowError subclass). WP2 needs it to tell the caller. Add a test.; #4 src/mem_mcp/mindmap/workflow_moves.py:~365 sign_workflow_move: the TEAM_WRITE_MEMORY requirement for signing is not in wp1.md. Check it against the plan and the permission model, and drop or justify it. Make the signoff insert and history use the signatory's tenant consistently with tenant_tx/RLS, or reject signatory_tenant_id != tenant_id. Also document the new workflow_id and immediate_only parameters on propose_move/move_work_item for WP2.; #5 tests/unit/mindmap/test_workflow_moves.py: add direct tests for the immediate_only path and the set_work_item_kind guard. Also test the legacy-routing MoveBlockedError cases. Only one test currently mentions mark_work_item.
Read first: see plan
Already finished tasks you build on: none

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

