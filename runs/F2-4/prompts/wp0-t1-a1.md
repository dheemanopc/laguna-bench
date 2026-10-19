You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp0.md` (read its DESIGN section and your task).

TASK WP0-T1: Migration 0048 + schema test: workflow tables, work_items/work_item_history extensions
Files you own: alembic/versions/0048_2026_10_17_team_workflows.py, tests/unit/test_migration_0048_workflow_schema.py
Tests the harness will run for you: tests/unit/test_migration_0048_workflow_schema.py
Acceptance: alembic upgrade head applies 0048 cleanly (down_revision=0047_work_item_history_rls_fix); 5 new tables (team_workflows, workflow_stages, workflow_transitions, workflow_signoff_requests, workflow_signoffs) exist with RLS enabled + tenant_id=safe_current_tenant_id() SELECT/INSERT policies and per-table grants (stages/transitions/signoffs: SELECT+INSERT only); work_items has nullable workflow_id→team_workflows (NO ACTION) + current_stage + work_items_tenant_team_current_stage_idx; work_item_history has stage_before/stage_after/workflow_id and change_type CHECK includes stage/signoff_requested/signoff_approved; deleting a team_workflows row is blocked (NO ACTION FK from work_items.workflow_id and work_item_history.workflow_id) once items or history reference it (R4)
Read first: alembic/versions/0046_2026_10_16_mindmap_work_items.py, alembic/versions/0034_2026_05_31_safe_current_tenant_id.py, alembic/versions/0011_2026_05_19_embedding_nullable.py, alembic/versions/0026_2026_05_29_personal_teams_visibility_fragments.py, tests/unit/test_migration_0026_schema.py, CONVENTIONS.md
Already finished tasks you build on: none

CONTINUATION: a previous session on this task ran out of its context budget before finishing. Your files already contain its work (inspect with `git diff HEAD -- <your files>`). Finish the task; read less this time.
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

