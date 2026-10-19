You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp3.md` (read its DESIGN section and your task).

TASK WP3-R1: fix WP3 review findings
Files you own: src/mem_mcp/main.py, src/mem_mcp/web/handlers/mindmaps.py, src/mem_mcp/web/handlers/workflows.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Tests the harness will run for you: tests/unit/test_web_mindmaps_router.py, tests/unit/test_web_mindmaps_work_items_router.py, tests/unit/test_web_workflows_router.py
Acceptance: #1 src/mem_mcp/web/handlers/mindmaps.py:343-349: the signoff endpoint ignores the map_key and node_id path params and builds its input from request_id alone. POST /work-items/{any node}/signoff can therefore sign a request that belongs to a different node or map. Verify, within the caller's team scope, that the request's node and map match the path. Return 404 if they don't, and add a test for the mismatch.; #2 tests/unit/test_web_workflows_router.py:50-63: only GET /workflow has a behavioural test. Add tests for create, activate, remap and pending-signoffs. They should cover the mapping of path/body params to the domain call, the list-shaped pending-signoffs response, the error mapping, and permission denial. The 401 test alone is not enough.; #3 tests/unit/test_web_mindmaps_work_items_router.py:57-137: no tests for get or history. Add assertions that board-list items carry current_stage, allowed_moves, blocked_reason and pending_signoffs (WP3-T2). Add a separate assertion that a move needing sign-off returns the signoff_required code.; #4 src/mem_mcp/web/handlers/workflows.py:70-72,142: RemapBody.mappings is typed Any and map_key silently defaults to 'default'. Type mappings as dict[str, str] and make map_key required, so a bad body gives a clean 422 and cannot remap the wrong map. Add a test for a malformed body.; #5 src/mem_mcp/web/handlers/workflows.py:45-61: the local _ctx_from_session wrapper writes into _mindmaps_mod.__dict__ to patch lookup_session. Production code should not carry test-only plumbing. Import _ctx_from_session from mindmaps.py directly and patch it in the tests.
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

