You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp3.md` (read its DESIGN section and your task).

TASK WP3-T1: Team workflows router: make_workflows_router (get/create/activate/remap/pending-signoffs) + main.py registration
Files you own: src/mem_mcp/web/handlers/workflows.py, src/mem_mcp/main.py, tests/unit/test_web_workflows_router.py
Tests the harness will run for you: tests/unit/test_web_workflows_router.py
Acceptance: make_workflows_router defined in web/handlers/workflows.py and included in main.py at main.py:567 (import at main.py:102); 5 endpoints present: GET/POST /teams/{team_id}/workflow, POST .../{workflow_id}/activate, POST .../remap, GET .../pending-signoffs; GET/POST create/activate/remap/pending-signoffs delegate to the correct WP2 tool, mapping team_id and workflow_id path params into the input model; all endpoints build ToolContext via _ctx_from_session (reused from mindmaps.py) and translate JsonRpcError via _http_from_jsonrpc (400 with code/data); without a valid mem_session cookie, every endpoint returns 401; unit test mocks each tool and asserts (a) 401 without session, (b) correct input-model construction from path params, (c) JsonRpcError.code surfaces in the 400 detail
Read first: src/mem_mcp/web/handlers/mindmaps.py, src/mem_mcp/main.py, src/mem_mcp/mcp/tools/_base.py, src/mem_mcp/mcp/tool_descriptions.py, src/mem_mcp/mindmap/workflow.py, tests/unit/test_web_mindmaps_router.py
Already finished tasks you build on: none

RETRY (attempt 3): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp3-t1-a2 (harness-run)
- ruff: FAIL
    tests/unit/test_web_workflows_router.py:52:5: F841 Local variable `out` is assigned to but never used
       |
    50 | def test_code_surfaces() -> None:
    51 |     client = _client()
    52 |     out = None
       |     ^^^ F841
    53 | 
    54 |     async def fake_call(ctx: Any, inp: Any) -> Any:
       |
       = help: Remove assignment to unused variable `out`
    
    Found 1 error.
    No fixes available (1 hidden fix can be enabled with the `--unsafe-fixes` option).
- mypy (this task's files): clean
- tests: 6 passed, 1 warning in 1.39s
RESULT: FAIL

Previous attempt's final message:
RESULT: DONE
CHANGED: src/mem_mcp/web/handlers/workflows.py
TESTS: ruff check src/mem_mcp/web/handlers/workflows.py -> All checks passed!; mypy src/mem_mcp/web/handlers/workflows.py -> Success: no issues found; pytest tests/unit/test_web_workflows_router.py -q -> 6 passed, 1 warning
NOTES: workflows.py now reuses mindmaps._ctx_from_session/_http_from_jsonrpc/_READ/_WRITE via import; lookup_session patch seam preserved for the existing test. main.py already registered router/import. none.
Fix the failures (CHECKLIST each gate failure).
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

