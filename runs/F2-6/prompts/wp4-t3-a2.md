You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-T3: WaitingOnYou panel (replaces T1 stub): pending-signoffs rows, node_id join to board items, inline Sign buttons
Files you own: web/app/mindmaps/[key]/board/WaitingOnYou.tsx
Tests the harness will run for you: none
Acceptance: implements WaitingOnYouProps from T1's stub; collapsible panel below board; GET /teams/{team_id}/workflow/pending-signoffs (team_id from WorkListOutput.team_id); each row looked up to board items by node_id (rows carry node_id, pinned + asserted by WP4-T5); row shows from_stage→to_stage, item title snippet, reason, signoff_count/signoff_min, remaining; inline Sign → POST /mindmaps/{map_key}/work-items/{node_id}/signoff {request_id} via csrfHeaders; 'committed'→bumpRefresh, 'awaiting_signoff'→update counts; signatory is session-resolved (never a UI field); 401→login redirect, 400 banner (signoff_complete); bumps boardRefreshKey; npx tsc --noEmit from web/ is green
Read first: web/app/mindmaps/[key]/board/BoardView.tsx, web/app/mindmaps/[key]/board/ItemDetail.tsx, web/lib/server-api.ts:49-90, web/lib/csrf.ts:20, docs/feature/wp2.md, CONVENTIONS.md
Already finished tasks you build on: WP4-T1 (Board page: server page.tsx (board-list + workflow fetch, 401/404) + BoardView client (ordinal columns, item cards, blocked badge, move dropdown) + BoardContext (shared boardRefreshKey) + stub ItemDetail/WaitingOnYou with prop interfaces)

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. `WaitingOnYou.tsx:98`: The code branches on `data.status === "committed"`, but the signoff endpoint has no `status` field. `MindmapWorkflowSignoffOutput` (`mindmap_workflow_signoff.py:27-34`) returns `{node_id, signed_count, signoff_min, committed: bool, request_id}`. The committed branch therefore never runs. A final sign-off that commits the move is handled as "awaiting": the row stays with a bumped count, and `remaining` comes out as 0. The row only disappears if the follow-up `load()` drops it.
2. `WaitingOnYou.tsx:16, 79, 144`: The panel assumes pending-signoff rows carry `node_id`, but the backend doesn't send it. `PendingSignoffOutput` (`_work_item_common.py:208-220`) has `memory_id` and no `node_id`, and the web handler (`workflows.py:116-128`) returns the tool output unchanged. No changed file adds `node_id` on the backend. At runtime `row.node_id` is `undefined`, so three things break:
   - The board-item join fails, and the title falls back to `undefined`. Then `title.length` at line 153 throws and crashes the panel.
   - The Sign URL becomes `/work-items/undefined/signoff`, which the `node_id: UUID` route rejects with a 422.
   - Neither the field name nor the missing backend field is reconciled. WP4-T5 is supposed to pin this field, but `PendingSignoffOutput` doesn't have it.
3. `WaitingOnYou.tsx:102`: The component reads `signatory_count ?? signed_count`. The real signoff response only has `signed_count`, so this fallback happens to work. The `row.signatory_count + 1` fallback shows the contract was guessed rather than checked, and `bumpRefresh` in that branch isn't required by the acceptance.
4. No test covers this component. No Playwright, vitest or integration test exercises the panel. The only check named is `tsc`, which can't catch the response-shape mismatches in items 1 and 2.
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

