You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-R1: fix WP5 review findings
Files you own: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Acceptance: #1 SignoffRequiredError is defined and mapped (src/mem_mcp/mcp/tools/_work_item_common.py:~249) but never raised in src/mem_mcp/mindmap, though docs/feature/wp5.md:49-51,212,253 expects `signoff_required` end to end. Find which path the plan means (a direct move or set_status on a sign-off-gated transition that bypasses propose_move). Make the domain layer raise SignoffRequiredError there, with no commit and no history row. Replace the mapping-only tests in tests/integration/test_mindmap_workflows_e2e.py:~500 and test_mindmap_workflow_web_e2e.py:~560 with real end-to-end assertions of MCP error data.code=='signoff_required' and web HTTP 400 detail.code=='signoff_required'. If the plan really doesn't require it, say so with the doc line cited.; #2 tests/integration/test_mindmap_workflows_e2e.py and test_mindmap_workflow_web_e2e.py have no non-member or cross-tenant isolation scenario. Add one in each. A tenant that is not in the team calls workflow_get, work_history, pending_signoffs, propose_move, signoff and remap (MCP), and the matching web routes, with that team_id. Each is refused (not found or forbidden), and no workflow_signoffs rows or item changes result.; #3 tests/integration/test_mindmap_workflow_signoff_remap_e2e.py:~264: `_expect_code` only checks data['code'] when data_code is not None. Make data_code a required argument and pass it at every call site, so no call skips the code check.
Read first: see plan
Already finished tasks you build on: none

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. Finding #1 is unresolved. No `src/mem_mcp/mindmap` file changed, so `SignoffRequiredError` is still never raised. The teammate didn't say the plan doesn't require it, and didn't cite a doc line. `docs/feature/wp5.md:49-51` leaves the raise condition to WP1/WP2, so declining to implement it is arguably defensible. That justification still has to be stated, and it isn't.
2. `tests/integration/test_mindmap_workflows_e2e.py:502` still holds the mapping-only `test_signoff_required_error_mapping` with its "GAP" docstring. The acceptance asked for it to be replaced with a real end-to-end assertion.
3. In `tests/integration/test_mindmap_workflow_web_e2e.py` (~560), the web mapping test was deleted and the non-member test took its place. Nothing now covers `signoff_required` → HTTP 400 `detail.code`, so the contract that `wp5.md:212,253` says WP5 asserts is untested on the web path.
4. `tests/integration/test_mindmap_workflow_web_e2e.py` non-member test: the refusal check accepts any of 400, 403 or 404, and nothing checks the error body. The MCP test pins the error to `errors == [{"path": "team_id"}]`, so the web test is weaker than its MCP counterpart.
5. `src/mem_mcp/web/handlers/workflows.py:62-71` gained an optional `workflow_id` query parameter on the GET workflow route. That is a production change nobody asked for in this task, and it has no test.

Finding #3 looks done: `data_code` is now required and the one `None` call site was rewritten.
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

