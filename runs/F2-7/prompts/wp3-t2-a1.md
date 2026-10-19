You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp3.md` (read its DESIGN section and your task).

TASK WP3-T2: Map board + item-action endpoints: work-items list/get/history/move/signoff in make_mindmaps_router
Files you own: src/mem_mcp/web/handlers/mindmaps.py, tests/unit/test_web_mindmaps_work_items_router.py
Tests the harness will run for you: tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_mindmaps_router.py
Acceptance: 5 endpoints added to make_mindmaps_router: GET /mindmaps/{map_key}/work-items, GET .../{node_id}, GET .../{node_id}/history, POST .../{node_id}/move, POST .../{node_id}/signoff; board-list GET maps query params (status, kind, assignee_id, unassigned, map_state, limit) + map_key path into MindmapWorkListInput(team_id=None); GET (board item) and POST (move/signoff) build MindmapWorkGetInput/WorkflowProposeMoveInput/WorkflowSignoffInput from path + body, signatory/identity from session ctx; move -> MindmapWorkflowProposeMoveTool, signoff -> MindmapWorkflowSignoffTool, list -> MindmapWorkListTool, get -> MindmapWorkGetTool, history -> MindmapWorkHistoryTool; board-list and get responses carry per-item current_stage, allowed_moves, blocked_reason, pending_signoffs (from WP2 WorkListItemOutput); move_blocked, signoff_required and signoff_complete JsonRpcErrors return 400 with the code in detail; no-session returns 401; existing tests/unit/test_web_mindmaps_router.py still passes (endpoints only added, no existing behaviour changed)
Read first: src/mem_mcp/web/handlers/mindmaps.py, src/mem_mcp/mcp/tools/_work_item_common.py, src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow.py, tests/unit/test_web_mindmaps_router.py
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

