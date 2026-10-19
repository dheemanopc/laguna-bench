You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-T3: workflow_moves.py + work_items.py move/route + _resolve_workflow
Files you own: src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/work_items.py, tests/unit/mindmap/test_workflow_moves.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_moves.py
Acceptance: move_work_item(conn,*,tenant_id,team_id,map_key,node_id,to_stage,reason,expected_stage,channel)->WorkItem in work_items.py resolves workflow via _resolve_workflow; _resolve_workflow returns item.workflow_id else team active else materialise_legacy_workflow; set_work_item_status/set_work_item_kind/mark_work_item route via move_work_item->propose_move (raising MoveBlockedError on disallowed moves) when workflow_id IS NOT NULL; unchanged when NULL; assign_work_item NOT routed; propose_move takes map_key+channel; FOR UPDATE; TransitionNotFoundError/reason/ReasonRequiredError; writes signoff_requests+history('signoff_requested') when requires_signoff WITHOUT advancing current_stage; else commits stage+history('stage'); sign_workflow_move: FOR UPDATE on request; owner/proposer excluded; UNIQUE prevents dup; commits at signoff_min; cancel only proposer/admin; cycle broken: work_items imports workflow_errors at top level, calls workflow_moves.propose_move via local import only
Read first: src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/work_items.py:195,285,351,377,422,448,594,606,706,810, src/mem_mcp/mindmap/service.py:63,54,166, src/mem_mcp/auth/rbac.py:28, src/mem_mcp/mcp/tools/mindmap_work_set_status.py:41, CONVENTIONS.md
Already finished tasks you build on: WP1-T1 (Shared workflow exception hierarchy in workflow_errors.py), WP1-T2 (workflow_crud.py: create/activate/get/materialise_legacy/remap)

RETRY (attempt 3): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp1-t3-a2 (harness-run)
- note: planned files not present: src/mem_mcp/mindmap/workflow_moves.py tests/unit/mindmap/test_workflow_moves.py
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — none of the planned test files exist (tests/unit/mindmap/test_workflow_moves.py)
RESULT: FAIL

Previous attempt's final message:


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

