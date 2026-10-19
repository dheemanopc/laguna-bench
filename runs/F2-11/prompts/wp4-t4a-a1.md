You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-T4a: Settings page + WorkflowSettingsClient shell (active view, create form, activate button, remap form, members fetch)
Files you own: web/app/teams/[team_id]/workflow/page.tsx, web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx
Tests the harness will run for you: none
Acceptance: page.tsx server component: serverApiFetchResult GET /teams/{team_id}/workflow + GET /teams/{team_id}/members (teams.py:500); 401→redirectTo, 404→notFound; passes WorkflowOutput + member role keys to WorkflowSettingsClient; active view shows stages (ordered list: name/is_initial/is_terminal/ordinal) and transitions table (from→to|requires_reason|requires_signoff|signoff_min|signoff_roles|allowed_kinds); create form POST /teams/{team_id}/workflow {name,stages[],transitions[]} via csrfHeaders; 422→field errors, 400→banner; on success renders workflow_id with an Activate button → POST …/{workflow_id}/activate (dropdown dropped: no WP3 list endpoint — future item); remap form POST /teams/{team_id}/workflow/remap {mappings:{old:new}}; shows WorkflowRemapOutput.updated_count toast; router.refresh() after any write; embeds <WorkflowEditor/> (T4b); npx tsc --noEmit from web/ is green
Read first: web/app/settings/TenantSettingsClient.tsx, web/app/settings/page.tsx, web/lib/server-api.ts:63-90, web/lib/csrf.ts:20, src/mem_mcp/web/handlers/teams.py:500-576, src/mem_mcp/mindmap/work_items.py:29, docs/feature/wp2.md, CONVENTIONS.md
Already finished tasks you build on: WP4-T4b (WorkflowEditor — pure stages/transitions editor (extracted from T4 to stay under 400 lines))

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

