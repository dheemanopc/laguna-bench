You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp3.md` (read its DESIGN section and your task).

TASK WP3-R1: fix WP3 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/web/handlers/mindmaps.py, src/mem_mcp/web/handlers/workflows.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Tests the harness will run for you: tests/unit/test_web_mindmaps_router.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Acceptance: #1 src/mem_mcp/web/handlers/mindmaps.py:~246-262: list_work_items hard-codes team_id=None, so a team board can't be loaded over the web API. Add an optional `team_id: UUID | None = None` query param and pass it to the mindmap_work_list tool, as get_map and queue do. Update tests/unit/test_web_mindmaps_work_items_router.py:95 to cover both None and a given team_id.; #2 src/mem_mcp/web/handlers/workflows.py:53-55: RemapBody requires `map_key`, but the wp3.md endpoint table specifies `{mappings{old→new}}`. The web UI package builds against this contract. If map_key is really needed by the tool, keep it, update wp3.md to say so, and make sure the UI task description uses the same body. Otherwise derive it server-side. Pin the final body shape in tests/unit/test_web_workflows_router.py.; #3 tests/unit/test_web_workflows_router.py and tests/unit/test_web_mindmaps_work_items_router.py: these only mock the tools. Add at least one test per router (workflows, work-item move/signoff/history) that goes through the real tool with a non-member session and a foreign team_id, and asserts the request is refused with the mapped HTTP error. This guards against the authorization bypass that earlier packages had.
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

