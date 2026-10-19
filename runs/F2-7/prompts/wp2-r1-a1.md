You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-R1: fix WP2 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/mcp/tool_descriptions.py, src/mem_mcp/mcp/tools/_work_item_common.py, src/mem_mcp/mcp/tools/mindmap_work_assign.py, src/mem_mcp/mcp/tools/mindmap_work_get.py, src/mem_mcp/mcp/tools/mindmap_work_history.py, src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_mark.py, src/mem_mcp/mcp/tools/mindmap_work_set_kind.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/mindmap_workflow_activate.py, src/mem_mcp/mcp/tools/mindmap_workflow_cancel_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_create.py, src/mem_mcp/mcp/tools/mindmap_workflow_get.py, src/mem_mcp/mcp/tools/mindmap_workflow_pending_signoffs.py, src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_remap.py, src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py, tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Tests the harness will run for you: tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Acceptance: #1 Identity mismatch: the sign-off, cancel-move, activate and remap tools pass `ctx.identity_id` (mindmap_workflow_signoff.py:59, mindmap_workflow_cancel_move.py:56, mindmap_workflow_activate.py:52, mindmap_workflow_remap.py:52). mindmap_workflow_pending_signoffs.py:49 passes `ctx.tenant_id`, and work_items.py:1081 stores the proposer/owner under one of the two ids. Determine which id the domain layer expects (propose_move uses `identity_id=ctx.identity_id` for the same fields). Use that one in every workflow tool, including pending_signoffs. Add an e2e test where the proposer cannot sign their own move, the proposer can cancel it, and pending_signoffs for the signer lists it.; #2 mindmap_workflow_pending_signoffs.py:35-77 and mindmap_work_history.py: the `list`-subclass-cast-to-BaseModel outputs (PendingSignoffListOutput and WorkItemHistoryListOutput in _work_item_common.py) with `-> Any` and a `cast` break the plan's typed outputs. Replace them with proper pydantic models that hold an `items: list[...]`. The error handling must also catch WorkflowError as well as WorkItemError, so permission denials map to JSON-RPC errors instead of escaping.; #3 mindmap_workflow_signoff.py:90 and mindmap_workflow_cancel_move.py:75 catch only WorkflowError. Catch WorkItemError too. Remove the raw SQL that reads signed_count and committed in a separate query. Have the domain function return those values from inside its FOR UPDATE transaction (extend the return type if needed).; #4 _work_item_common.py:~110: make WorkflowDetailOutput a subclass or alias of WorkflowOutput instead of a field-for-field copy, so WP3 has a single source for the shape.; #5 Error mapping in _work_item_common.py:~376: role_restricted/SignoffNotAllowedError is documented as -32000 but maps to -32602. There is no mapping for not_pending, not_eligible or cancel_not_allowed, so they fall to a generic error. Make the codes match the WP2 doc (check docs/feature/wp2.md) and add unit tests in tests/unit/test_workflow_error_mapping.py for each WorkflowError subclass.
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

