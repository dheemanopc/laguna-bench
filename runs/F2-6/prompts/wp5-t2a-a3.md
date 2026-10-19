You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-T2a: Integration e2e (MCP path) — define→propose(sign-off)→sign→commit, no-signoff commit, set_status gate, sign-off exclusion + role restriction, remap/unmapped, blocked reasons, codes — tests/integration/test_mindmap_workflows_e2e.py
Files you own: tests/integration/test_mindmap_workflows_e2e.py
Tests the harness will run for you: tests/integration/test_mindmap_workflows_e2e.py
Acceptance: pg_pool + NoopAuditLogger/stub embed + _build_deps/_ctx/_setup/_cleanup replicated from test_mindmap_work_items_e2e.py:47-57,158-167,60-168; UUID-suffixed team/workflow/work item; owner(tenant_a)+signatory(tenant_b) contexts; skipif MEM_MCP_TEST_DSN unset; define workflow (mindmap_workflow_create) → create items (mindmap_work_mark) → propose_move on a signoff-gated transition returns ProposeMoveOutput.awaiting_signoff=true with request_id and does NOT advance current_stage; workflow_signoff_requests.status='pending'; sign_workflow_move by eligible signatories: current_stage advances + 'stage'/'signoff_approved' history appended + request.status='committed' only at signoff_min; owner/proposer-only signs keep it pending (sign-off exclusion); no-signoff move commits current_stage immediately (no request row) + 'stage' history row; set_status gate: mindmap_work_set_status on a workflow-backed item targeting a signoff-gated transition raises JsonRpcError(-32602) with data.code='move_blocked'; current_stage unchanged; signoff role restriction: a signer outside signoff_roles is rejected (does not count) by mindmap_workflow_signoff; signoff_required surfaces as JsonRpcError(-32602, data.code='signoff_required') from mindmap_workflow_propose_move under the WP1/WP2-defined condition; blocked reasons via mindmap_work_list allowed_moves/blocked_reason: reason_required (blank reason), no_transition (terminal/unmapped), role_restricted, 'awaiting N sign-offs'; remap (mindmap_workflow_remap): unmapped items keep current_stage; board-list (mindmap_work_list) still returns them with current_stage + empty allowed_moves; pending-signoffs read (mindmap_workflow_pending_signoffs) lists only eligible requests with signoff_min/signoff_count/remaining; error code+data asserted, not just no-exception
Read first: src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py, src/mem_mcp/mcp/tools/mindmap_workflow_remap.py, src/mem_mcp/mcp/tools/mindmap_workflow_pending_signoffs.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_history.py, src/mem_mcp/mcp/tools/_work_item_common.py:56-195, src/mem_mcp/mindmap/workflow.py, docs/feature/wp1.md, docs/feature/wp2.md, tests/integration/test_mindmap_work_items_e2e.py, tests/conftest.py, CONVENTIONS.md
Already finished tasks you build on: none

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. tests/integration/test_mindmap_workflows_e2e.py:1-60: There is no module-level `pytestmark = skipif(not os.getenv("MEM_MCP_TEST_DSN"))`. The acceptance asks for it, and `test_mindmap_work_items_e2e.py:41` has it. The tests only skip indirectly through the `pg_pool` fixture.
2. tests/integration/test_mindmap_workflows_e2e.py:~395-400: The role_restricted check for a viewer is weak. It asserts `exc.value.code in {-32000, -32603}` and never checks `data.code`. It also reads the blocked reason by calling `compute_item_moves` directly, not through `mindmap_work_list`'s `allowed_moves` as the acceptance requires.
3. tests/integration/test_mindmap_workflows_e2e.py:~410-425: `signoff_required` is only tested as a pure unit mapping of a hand-built `SignoffRequiredError`, not through `mindmap_workflow_propose_move`. `SignoffRequiredError` is never raised anywhere in `src/mem_mcp/mindmap`, so the acceptance's "under the WP1/WP2-defined condition" isn't exercised end to end. The test also never mentions that gap.
4. tests/integration/test_mindmap_workflows_e2e.py:~455-480: The remap test doesn't verify that unmapped items keep their `current_stage`. Every item is mapped (`todo`→`backlog`, `updated_count == 2`), so no item is left unmapped after the remap. The "keeps current_stage" assertions all run before the remap.
5. tests/integration/test_mindmap_workflows_e2e.py:~335: The no-transition case accepts `data.code in {"transition_not_found", "move_blocked"}`. That is a loose assertion where the exact code should be pinned.
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

