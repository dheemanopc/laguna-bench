You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-T1a: Domain lifecycle unit tests (create/activate/get/legacy-materialise/remap + workflow-change preservation) — tests/unit/mindmap/test_workflow.py
Files you own: tests/unit/mindmap/test_workflow.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow.py
Acceptance: pg_pool + tenant_tx + NoopAuditLogger/stub embed pattern from test_mindmap_work_items_e2e.py:47-57,158-167; UUID-suffixed team/workflow/item; seeds team_role_assignments owner(member) like e2e.py:78-93; skipif MEM_MCP_TEST_DSN unset; create_team_workflow writes team_workflows(is_active=false,version=1)+workflow_stages+workflow_transitions; invalid allowed_kinds/dup name raises a WorkflowError subclass; non-TEAM_WRITE role raises WorkflowPermissionDeniedError; all SQL has explicit tenant_id; activate_workflow flips exactly one active per team (partial UNIQUE) and bumps version; re-activating the same workflow raises WorkflowAlreadyActiveError; get_workflow returns the active workflow (or the named id) with stages ordered by ordinal + transitions; materialise_legacy_workflow is idempotent (INSERT ON CONFLICT team_id,name DO NOTHING) under _legacy/is_active=false; stages match WORK_STATUSES/TRANSITIONS and never require signoff; _resolve_workflow: NULL workflow_id resolves to the legacy workflow with current_stage=status; after activating a new workflow, items keep their old workflow_id and stage; history rows keep stage_before/stage_after/workflow_id; remap_workflow_stages requires TEAM_WRITE; updates current_stage for mapped stage names + returns updated_count; unmapped items keep current_stage; DB state asserted via raw asyncpg queries against pg_pool (not return values)
Read first: src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/work_items.py:29-47,195-229,285,351,377,422, src/mem_mcp/mindmap/service.py:54,63,166, src/mem_mcp/auth/rbac.py:28, src/mem_mcp/auth/permissions.py:70, alembic/versions/0046_2026_10_16_mindmap_work_items.py, docs/feature/wp0.md, docs/feature/wp1.md, tests/integration/test_mindmap_work_items_e2e.py, tests/conftest.py, CONVENTIONS.md
Already finished tasks you build on: none

RETRY with guidance from the delivery lead:
The tests pass, but the harness rejects the module-level `pytestmark = pytest.mark.skipif(...)` at test_workflow.py:46. Delete it. Don't replace it with another skip, xfail or importorskip.
Check how neighbouring DB tests (tests/unit/mindmap/test_workflow_crud.py, test_workflow_moves.py) get a database. Use the same fixtures from conftest, and no env-var skip. If the DB is missing, the test should fail loudly.
Don't weaken any assertion. Run `pytest tests/unit/mindmap/test_workflow.py -q` and confirm the tests run (0 skipped), then run ruff and mypy on the file.
Last gate output:
## Gate for wp5-t1a-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 17 passed in 5.71s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 46:+pytestmark = pytest.mark.skipif(
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

