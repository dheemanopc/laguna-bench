You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-R1: fix WP4 review findings
Files you own: tests/integration/test_mindmap_workflow_web_ui_shapes.py, web/app/mindmaps/[key]/board/BoardContext.tsx, web/app/mindmaps/[key]/board/BoardView.tsx, web/app/mindmaps/[key]/board/ItemDetail.tsx, web/app/mindmaps/[key]/board/WaitingOnYou.tsx, web/app/mindmaps/[key]/board/page.tsx, web/app/teams/[team_id]/workflow/WorkflowEditor.tsx, web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx, web/app/teams/[team_id]/workflow/page.tsx
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Acceptance: #1 ItemDetail.tsx:10 is still the T1 stub (`return null`), so "Move to…" in BoardView.tsx:146-161 opens nothing. Implement it per docs/feature/wp4.md. It needs: item detail with its history; a move-target picker listing allowed and blocked moves from compute_item_moves, with the full blocked reason for each blocked one; a reason textarea when requires_reason; a propose-move call that handles the pending-sign-off result; a sign-off/cancel panel; and an error banner that shows the server's error message, not a generic failure. Call the existing handler endpoints and use the csrfHeaders helper.; #2 BoardView.tsx:84-95: blocked cards show only a terse badge. Show the sign-off progress (for example 'awaiting 1 of 2' with the sign-off roles) and the specific blocked reason on the card or in its tooltip. In the ItemDetail panel, show who has signed and who can still sign.; #3 WaitingOnYou.tsx:63-125: the fetch effect ignores `refreshKey`, so the list goes stale after a move or sign-off. Add `refreshKey` to the deps. Take the item titles from BoardView as a prop instead of re-fetching the board's work items. After a sign-off in ItemDetail, trigger the refresh.; #4 WaitingOnYou.tsx:141-190 and ItemDetail: use the shared `csrfHeaders` and 401 handling from csrf.ts:20 in place of the hand-written fetch headers and `window.location.href` redirects. Put them in one small helper that the board components share.; #5 Add frontend or integration tests for the new UI flows. Cover the move requiring a reason, a blocked move showing its reason, sign-off by an eligible user, and the error banner. Follow the existing web test setup in web/ if there is one. If none exists, extend tests/integration/test_mindmap_workflow_web_ui_shapes.py to pin the request and response shapes that ItemDetail uses.
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

