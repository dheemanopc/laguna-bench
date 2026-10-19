You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-T4b: WorkflowEditor — pure stages/transitions editor (extracted from T4 to stay under 400 lines)
Files you own: web/app/teams/[team_id]/workflow/WorkflowEditor.tsx
Tests the harness will run for you: none
Acceptance: 'use client' presentational component; props {stages:string[], teamRoles:string[], workKinds:readonly string[], onStagesChange, onTransitionsChange} matching T4a's call site; renders ordered stages[] rows (name, is_initial, is_terminal; ordinal inferred) + transitions[] rows (from_stage select incl 'any', to_stage select, requires_reason, requires_signoff, signoff_min min1-when-signoff, signoff_roles multi-select from teamRoles, allowed_kinds multi-select from workKinds); add/remove rows; pure: no fetch, no writes, no router — keeps T4a under 400 lines; submission owned by T4a; npx tsc --noEmit from web/ is green
Read first: web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx, src/mem_mcp/mindmap/work_items.py:29, src/mem_mcp/web/handlers/teams.py:500, CONVENTIONS.md
Already finished tasks you build on: none

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. WorkflowEditor.tsx:49,106 — Renaming or removing a stage never updates `transitions`. Say a transition goes from "Review" to "Done", and the user renames "Done" to "Shipped". The transition still points at "Done", which is no longer in the options, so the select shows a wrong or blank value. Submission then sends a dangling stage name. The component is the only place that can keep the two lists in sync, because it owns both change callbacks.
2. WorkflowEditor.tsx:92,118 — `is_initial` can be ticked on several stages, and can be left on none, since this is a plain checkbox. Remove can also delete the initial stage and leave no initial one. The plan calls for an initial stage, and nothing here enforces it or warns about it. This is a minor point if T4a validates.
3. WorkflowEditor.tsx:23-30 — The props include a `transitions: TransitionDraft[]` field. The acceptance and plan list `{stages:string[], teamRoles, workKinds, onStagesChange, onTransitionsChange}`, and say `stages` is `string[]`, whereas this takes `StageDraft[]`. T4a doesn't exist yet, so I couldn't check the call site. The `transitions` prop is needed in practice, but the signature differs from the spec and T4a must match it.
4. WorkflowEditor.tsx:152-158 — `to_stage` defaults to "" when there are no stages. The "Select…" option only shows while the value is "", so a `to_stage` whose stage was removed has no matching option. Nothing flags it to the user.
5. I couldn't run `npx tsc --noEmit` (the command needed approval), so "tsc is green" is unverified.
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

