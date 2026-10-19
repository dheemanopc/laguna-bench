You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp3.md` (read its DESIGN section and your task).

TASK WP3-R1: fix WP3 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/web/handlers/mindmaps.py, src/mem_mcp/web/handlers/workflows.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Tests the harness will run for you: tests/unit/test_web_mindmaps_router.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Acceptance: #1 mindmaps.py:318-340: the signoff route ignores `{map_key}` and `{node_id}` and passes `team_id=None`. A request_id belonging to another node or map can be signed through this URL. Verify that the request's map and node match the path params and return 404 if not. Add a test for a mismatched node/map. Check that team resolution for the reads and move (mindmaps.py:239-310) follows the plan's rule, and use the map's own team where the plan says so.; #2 workflows.py:61: `pool: Any` loosens typing. Use `asyncpg.Pool`, via the same typing approach as mindmaps.py, with no new `type: ignore`.; #3 workflows.py:50-58: WorkflowCreateBody has no limits on stages/transitions and can drift from MindmapWorkflowCreateInput. Reuse the MCP input models or share their constraints (max counts, string lengths). Add a test for an oversized body returning 422.; #4 Add router tests that mock WorkflowError subclasses (move_blocked, signoff_required, not_pending, signoff_not_allowed, not found, permission denied). Assert each returns the planned 4xx status and never 500. Cover both routers.; #5 workflows.py:118: remap audit details record map_key='*'. Document this with a short comment next to the remap handler, or omit map_key if the audit schema allows. Keep the audit consistent with the other workflow routes.
Read first: see plan
Already finished tasks you build on: none

RETRY with guidance from the delivery lead:
mindmaps.py already had `import asyncpg  # type: ignore[import-untyped]` at baseline (commit 5406436, line 21). Restore that exact line as a top-level import. It is not an added line, so the harness won't flag it. The previous attempt wrongly removed it.
In workflows.py, don't import asyncpg. Add `Pool = asyncpg.Pool` next to `Conn = asyncpg.Connection` in mindmap/work_items.py, and use `from mem_mcp.mindmap.work_items import Pool` for `pool: Pool`.
Don't use `Any` and don't add any new `type: ignore`.
Check with `git diff 5406436 | grep '^+.*type: ignore'`, which must print nothing. Then re-run ruff, mypy and pytest.
Last gate output:
## Gate for wp3-r1-a3 (harness-run)
- ruff: clean
- mypy (this task's files): FAIL
    src/mem_mcp/web/handlers/mindmaps.py:25: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
    src/mem_mcp/web/handlers/mindmaps.py:25: note: See https://mypy.readthedocs.io/en/stable/running_mypy.html#missing-imports
    src/mem_mcp/web/handlers/workflows.py:16: error: Skipping analyzing "asyncpg": module is installed, but missing library stubs or py.typed marker  [import-untyped]
- tests: 58 passed, 43 warnings in 4.20s
RESULT: FAIL

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

