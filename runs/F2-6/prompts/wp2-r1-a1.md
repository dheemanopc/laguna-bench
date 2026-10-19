You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-R1: fix WP2 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/mcp/tool_descriptions.py, src/mem_mcp/mcp/tools/_work_item_common.py, src/mem_mcp/mcp/tools/mindmap_work_assign.py, src/mem_mcp/mcp/tools/mindmap_work_get.py, src/mem_mcp/mcp/tools/mindmap_work_history.py, src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_mark.py, src/mem_mcp/mcp/tools/mindmap_work_set_kind.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/mindmap_workflow_activate.py, src/mem_mcp/mcp/tools/mindmap_workflow_cancel_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_create.py, src/mem_mcp/mcp/tools/mindmap_workflow_get.py, src/mem_mcp/mcp/tools/mindmap_workflow_pending_signoffs.py, src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_remap.py, src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py, tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Tests the harness will run for you: tests/integration/test_mindmap_work_history_pending_e2e.py, tests/integration/test_mindmap_work_list_get_e2e.py, tests/integration/test_mindmap_workflow_crud_e2e.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py, tests/integration/test_mindmap_workflow_tools_registered.py, tests/integration/test_workflow_tool_gate.py, tests/unit/test_workflow_error_mapping.py, tests/unit/test_workflow_tool_descriptions.py
Acceptance: #1 src/mem_mcp/mcp/tools/mindmap_work_history.py:49-58 is an authorization bypass. It calls get_work_item_history with tenant_id=team_tenant (the team creator's tenant), so get_team_role(conn, tenant_id, team_id) in work_items.py:~1439 checks the creator and always passes. Any authenticated tenant can read any team's item history. Pass the caller's ctx.tenant_id for the membership and visibility check, and use team_tenant only for data access if needed. Add an integration test in tests/integration/test_mindmap_work_history_pending_e2e.py where a non-member calls history and is rejected.; #2 src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py:20-31: resolve_team_tenant returns the creator tenant of any existing team without checking that the caller is a member. Move it to _mindmap_common.py and make it verify the caller's team membership (or return the same not-found error for non-members). Then check that cancel, remap, signoff, history and pending_signoffs each reject a non-member. Add a non-member test for each tool.; #3 src/mem_mcp/mcp/tools/mindmap_workflow_create.py:81, mindmap_workflow_activate.py:42 and mindmap_workflow_get.py:42 use the caller's ctx.tenant_id, but the other workflow tools use team_tenant. A workflow created by a non-creator team member lives in a different tenant from the team's items, so later lookups under team_tenant won't find it. Use the same tenant convention as the domain layer and the other tools. Add an e2e test where a non-creator member creates and activates a workflow and then moves an item.; #4 src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py:105 calls the private workflow_moves._find_transition and re-queries the signed count. Have the domain function return signed_count, signoff_min and committed, and use that. Make the output match the plan's {node_id, signed_count, signoff_min, committed}, or document any extra field. Don't call private domain functions from the tool layer.; #5 src/mem_mcp/mcp/tools/_work_item_common.py:260-320 and the propose_move and signoff tools map SignoffNotAllowedError and related errors to -32602. wp2.md specifies -32000 with code role_restricted for role-restricted signers. Fix the mapping to match the plan, and add tests in tests/unit/test_workflow_error_mapping.py and the signoff e2e test that assert the code and data.
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

