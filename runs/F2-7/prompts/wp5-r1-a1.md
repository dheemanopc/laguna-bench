You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-R1: fix WP5 review findings
Files you own: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Acceptance: #1 The 6 new failures are in tests/unit/test_web_mindmaps_work_items_router.py (signoff tests, ~lines 334-560). They come from src/mem_mcp/web/handlers/mindmaps.py:94-123. `_verify_signoff_request_belongs_to_node` uses `tenant_tx(pool, tenant_id)` and `conn.fetchrow`. The tests mock `pool.acquire` and `fetchval` side effects `[node_id, map_key]`, so the helper raises and the tests get 500s. The tests and handler were written against different designs. Fix the handler and the tests together. Don't loosen any assertion, skip a test or delete one. Update the mocks to the shape the handler really uses (patch `tenant_tx`, or use the repo's fake-pool fixture). Then run the 6 tests plus the whole file and confirm they pass. Check with `git log -p` which change broke them.; #2 Cross-map hole: the signoff handler ignores `map_key` (mindmaps.py ~:366). The verify helper must join the sign-off request to its work item, node and map. It must return 404 when request_id belongs to a different node or map than the URL path, or to another tenant or team. Keep test_signoff_request_must_belong_to_specified_map and the node variant, with real assertions (404 plus no sign-off performed). Also remove the dead `client = _client()` reassignment around line 442-475 of the test file.; #3 The WP5 coverage review was not completed. Before approval, check that the e2e tests cover: a custom workflow with requires_reason and multi-person non-owner sign-off; history preserved and no stuck items after remap and workflow change; the board and waiting-on-you; MCP and web parity. Run `git diff 5406436 -- tests | grep -E '^\+.*(type: ignore|xfail|skip|noqa)'` and fix anything it finds.
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

