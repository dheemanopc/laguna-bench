You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-R1: fix WP2 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/mcp/tool_descriptions.py, src/mem_mcp/mcp/tools/_work_item_common.py, src/mem_mcp/mcp/tools/mindmap_work_assign.py, src/mem_mcp/mcp/tools/mindmap_work_get.py, src/mem_mcp/mcp/tools/mindmap_work_history.py, src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_mark.py, src/mem_mcp/mcp/tools/mindmap_work_set_kind.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/mindmap_workflow_activate.py, src/mem_mcp/mcp/tools/mindmap_workflow_cancel_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_create.py, src/mem_mcp/mcp/tools/mindmap_workflow_get.py, src/mem_mcp/mcp/tools/mindmap_workflow_pending_signoffs.py, src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_remap.py, src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py, tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Tests the harness will run for you: tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Acceptance: #1 tests/integration/test_mindmap_workflow_signoff_remap_e2e.py:1 and tests/integration/test_mindmap_work_history_pending_e2e.py:1 only assert that classes import. Write real DB-state e2e tests for: signoff commit once signoff_min is reached, owner/proposer exclusion, cancel permissions, remap updated_count, history rows, and pending-signoff filtering per user.; #2 tests/integration/test_workflow_tool_gate.py:1 is import-only. Add tests that a disallowed legacy transition via set_status (and set_kind/mark) returns JSON-RPC -32602 with a move_blocked payload, and that an allowed transition succeeds.; #3 src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py:76-145 runs raw SQL in the tool to recompute signed_count and signoff_min. The queries on workflow_signoff_requests, work_items, team_workflows and workflow_signoffs have no team_id filter. Move this logic into the workflow_moves/workflow_reads domain layer, which must scope by team_id under tenant_tx. Replace `assert req is not None` with a proper -32602 error. Make sure no write can happen on a read-after-commit path.; #4 src/mem_mcp/mcp/tools/mindmap_workflow_remap.py:41-50 uses map_key only to check the map exists. remap_workflow_stages (workflow_crud.py:540) takes no map_key, remaps by the team's active workflow, and can create a legacy workflow as a side effect. Scope the remap to the given map, or document and validate the intended scope. Do not have remap create a workflow implicitly. Test it.; #5 src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py:66 and mindmap_workflow_cancel_move.py:62 detect 'not pending' with `str(e) == "request not pending"`. Use a typed exception in workflow_errors.py instead. Route not_eligible and not_pending through the shared map_work_item_error. Make the error types caught in mindmap_work_history.py:120 and mindmap_workflow_pending_signoffs.py:51 consistent. Add unit cases to test_workflow_error_mapping.py.
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

