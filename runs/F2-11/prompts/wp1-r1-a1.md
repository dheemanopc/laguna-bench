You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-R1: fix WP1 review findings
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Acceptance: #1 tests/unit/mindmap/test_workflow_moves.py:1-14 is only an import smoke test. Add real tests for propose_move, sign_workflow_move, cancel_workflow_move and move_work_item. They must cover: the owner/assignee being excluded from sign-off, the move committing once signoff_min is reached, a duplicate sign, who may cancel, StageConflictError, MoveBlockedError, and the status/kind routing from work_items.py.; #2 src/mem_mcp/mindmap/workflow_moves.py:185-256 and the commit at :357 update only current_stage. They never sync work_items.status, so the WorkItem that comes back has a stale status and legacy status readers diverge from the stage. Update status together with the stage, per wp1.md, so the re-queried item reflects the commit.; #3 src/mem_mcp/mindmap/workflow_moves.py:305-323: sign_workflow_move does not require TEAM_WRITE_MEMORY on the signer. A viewer can therefore sign when signoff_roles is NULL. Add that permission check and read the assignee/owner used for the exclusion inside the same tenant_tx, after the role checks.; #4 src/mem_mcp/mindmap/work_items.py:456: mark_work_item is not routed through the workflow, unlike set_work_item_status and set_work_item_kind. Route it. Make set_work_item_kind raise MoveBlockedError with a meaningful current_stage and requested_stage, not equal values. Remove the duplicate workflow resolution and backfill in move_work_item (:1343-1380), which propose_move already does.; #5 src/mem_mcp/mindmap/workflow_crud.py:522-570: remap_workflow_stages does not check that the target stage exists in the team's active workflow. It also does not scope to the workflow or update status, and it does not set updated_at. A missing key becomes the string 'None' through str(old). Validate the target stage, reject missing keys, and set updated_at and status.
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
- Typing with asyncpg: rows/fetchval return Any. Under mypy --strict, convert explicitly instead of silencing:
  `return cast("UUID", row["id"])` / `cast("str", value)` (see src/mem_mcp/mindmap/work_items.py). The only allowed
  suppression in the repo is the existing `import asyncpg  # type: ignore[import-untyped]` (asyncpg has no stubs).
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

