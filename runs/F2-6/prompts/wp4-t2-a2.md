You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-T2: ItemDetail modal (replaces T1 stub): move dropdown+reason textarea+signoff confirm, signoff panel, history timeline, blocked badge, 400 banner
Files you own: web/app/mindmaps/[key]/board/ItemDetail.tsx
Tests the harness will run for you: none
Acceptance: implements the ItemDetailProps interface from T1's stub; move section: dropdown from allowed_moves (AllowedMoveOutput.to_stage); reason_required shows required textarea; requires_signoff shows confirm dialog before POST /mindmaps/{map_key}/work-items/{node_id}/move {to_stage,reason?,expected_stage?} via csrfHeaders+same-origin; 'committed'→bumpRefresh+close, 'awaiting_signoff'→show pending request state; signoff panel: pending_signoff signoff_count/signoff_min/remaining + Sign button → POST …/signoff {request_id}; 'committed'→bumpRefresh, 'awaiting_signoff'→update counts; 400 error banner shows detail.code+detail.message (move_blocked, reason_required, signoff_required, signoff_complete); history on open via GET …/{node_id}/history rendering stage_before/stage_after/workflow_id per change_type; npx tsc --noEmit from web/ is green
Read first: web/app/mindmaps/[key]/board/BoardView.tsx, web/app/mindmaps/[key]/graph-view.tsx:412-430, web/lib/server-api.ts:63-90, web/lib/csrf.ts:20, src/mem_mcp/mcp/tools/_work_item_common.py:39-53, CONVENTIONS.md
Already finished tasks you build on: WP4-T1 (Board page: server page.tsx (board-list + workflow fetch, 401/404) + BoardView client (ordinal columns, item cards, blocked badge, move dropdown) + BoardContext (shared boardRefreshKey) + stub ItemDetail/WaitingOnYou with prop interfaces)

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. `web/app/mindmaps/[key]/board/ItemDetail.tsx:~96,~222`: The textarea only becomes required (`reasonRequired`) after the server returns a 400 `reason_required`. The acceptance says a `reason_required` move shows the required textarea. The code never reads `move?.blocked_reason === "reason_required"` from `allowed_moves`. The user can therefore submit an empty reason and get an error instead of being blocked up front. `reasonRequired` is also never reset when the user picks a different stage, so it stays required for moves that don't need a reason.
2. `ItemDetail.tsx:~172,~196`: The Sign button ignores `pending.eligible_to_sign`. After a successful sign that doesn't commit, `eligible_to_sign` is set to false, but the button stays enabled and the user can sign again. It is also shown to people who aren't eligible signatories, who then get a 400 instead of a disabled button.
3. `ItemDetail.tsx:~50`: The history effect depends on `item.pending_signoff`, which is the prop, not the local `pending` state. After a move or sign-off inside the modal, the timeline isn't refetched. It only refreshes if the board re-renders and passes a new object. A sign-off that doesn't commit leaves the history stale.
4. `ItemDetail.tsx:~63-70`: `describeEntry` picks the stage format with `change_type.includes("stage")`, `stage_before` or `stage_after`. It doesn't branch on the actual `change_type` values, such as `signoff_requested` or `signoff`. The plan says to render per `change_type`. For other types it falls back to a status transition, which is unclear for sign-off rows. The code was not checked against the real `change_type` values.
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

