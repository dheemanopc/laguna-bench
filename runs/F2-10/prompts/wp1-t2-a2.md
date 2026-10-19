You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-T2: workflow_crud.py: create/activate/get/materialise_legacy/remap
Files you own: src/mem_mcp/mindmap/workflow_crud.py, tests/unit/mindmap/test_workflow_crud.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py
Acceptance: create_team_workflow requires TEAM_WRITE_MEMORY (else WorkflowPermissionDeniedError); inserts team_workflows+stages+transitions atomically; is_active=false, version=1; activate_workflow requires TEAM_WRITE_MEMORY; sets one active per team (partial UNIQUE) and bumps version; materialise_legacy_workflow inserts _legacy (is_active=false) via INSERT ON CONFLICT (team_id,name) DO NOTHING; idempotent under concurrency; stages match WORK_STATUSES/TRANSITIONS; get_workflow returns active workflow (+ordered stages/transitions) or named id; remap_workflow_stages requires TEAM_WRITE_MEMORY; updates current_stage for mapped stages and returns count; all SQL has explicit tenant_id=$n + RLS; pytest -q passes after alembic upgrade head
Read first: src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/work_items.py:29-47,377,422, src/mem_mcp/mindmap/service.py:63,54,166, src/mem_mcp/auth/rbac.py:28, src/mem_mcp/auth/permissions.py:70, alembic/versions/0046_2026_10_16_mindmap_work_items.py, CONVENTIONS.md, tests/unit/test_work_items_service.py
Already finished tasks you build on: WP1-T1 (Shared workflow exception hierarchy in workflow_errors.py)

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp1-t2-a1 (harness-run)
- note: planned files not present: tests/unit/mindmap/test_workflow_crud.py
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — none of the planned test files exist (tests/unit/mindmap/test_workflow_crud.py)
RESULT: FAIL

Previous attempt's final message:
RESULT: DONE

CHANGED: src/mem_mcp/mindmap/workflow_crud.py

TESTS:
- alembic upgrade head -> exit=0
- ruff check src/mem_mcp/mindmap/workflow_crud.py -> All checks passed
- mypy src/mem_mcp/mindmap/workflow_crud.py -> Success: no issues found
- python tools/lint_tenant_scope.py src/... -> (ran on file; no violations)
- pytest tests/unit/mindmap/test_smoke_crud_tmp.py -q (temporary DB smoke) -> 1 passed in 1.07s
- pytest tests/unit/mindmap/test_workflow_errors.py -q -> 8 passed in 0.98s

NOTES:
- create_team_workflow gates permission on `created_by` as actor (falls back to tenant_id); hidden DB tests using a viewer as created_by would be denied as intended.
- get_workflow raises WorkflowNotFoundError when no active/named workflow exists rather than returning None.
- Stage/transition inputs are normalised from strings/dicts/tuples/objects to tolerate alternate shapes hidden tests may use.
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

