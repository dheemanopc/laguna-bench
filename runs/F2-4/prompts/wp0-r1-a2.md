You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp0.md` (read its DESIGN section and your task).

TASK WP0-R1: fix WP0 review findings
Files you own: alembic/versions/0048_2026_10_17_team_workflows.py, tests/unit/test_migration_0048_workflow_schema.py
Tests the harness will run for you: tests/unit/test_migration_0048_workflow_schema.py
Acceptance: #1 In tests/unit/test_migration_0048_workflow_schema.py (RLS tests around lines 92-134 and the R4 delete tests around 307-378), add behavioural RLS and grant tests that run as the app role (mem_app), not as the pool owner. Cover three cases. Tenant A cannot SELECT or INSERT tenant B's rows in the new tables. UPDATE and DELETE are refused on workflow_stages, workflow_transitions and workflow_signoffs. A workflow that items or history still reference cannot be deleted. The current R4 delete tests run as the owner, so they would pass even without the grants.; #2 In the same test file, add constraint tests. Cover the partial unique index team_workflows_active_per_team (a second active workflow for the same team is rejected, while an inactive one is allowed). Cover unique (team_id, name). Cover the signoff_requests status CHECK (a bad value is rejected) and signoff_min >= 1 (0 is rejected). Cover the extended change_type CHECK (inserting 'stage', 'signoff_requested' and 'signoff_approved' succeeds, and a bogus value is rejected). Also assert that the partial unique index allows only one pending request per work item.; #3 In alembic/versions/0048_2026_10_17_team_workflows.py (downgrade, around lines 276-290), add a comment saying the downgrade fails if stage, signoff_requested or signoff_approved history rows exist. Add a downgrade/upgrade round-trip test on an empty schema (the plan's NOTES promise one).
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

