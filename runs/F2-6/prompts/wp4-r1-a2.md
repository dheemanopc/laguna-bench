You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-R1: fix WP4 review findings
Files you own: tests/integration/test_mindmap_workflow_web_ui_shapes.py, web/app/mindmaps/[key]/board/BoardContext.tsx, web/app/mindmaps/[key]/board/BoardView.tsx, web/app/mindmaps/[key]/board/ItemDetail.tsx, web/app/mindmaps/[key]/board/WaitingOnYou.tsx, web/app/mindmaps/[key]/board/page.tsx, web/app/teams/[team_id]/workflow/WorkflowEditor.tsx, web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx, web/app/teams/[team_id]/workflow/page.tsx
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Acceptance: #1 web/app/mindmaps/[key]/board/page.tsx:235-237: for a team with no active workflow, workflow_get returns HTTP 400 (WorkflowNotFoundError), not 404. The board page throws 'Failed to load workflow' and crashes. Treat 400 and 404 as 'no workflow', as teams/[team_id]/workflow/page.tsx:319 does. Then render the board as a legacy board with no transitions, and add a test or check for that case.; #2 web/app/mindmaps/[key]/board/WaitingOnYou.tsx:437-447: the pending-signoffs list covers the whole team, but each row is looked up in this map's items and signed through this mapKey's URL. Rows for other maps show a raw UUID, and their Sign call goes to the wrong map. Only show rows whose node_id is on this board (or label the others and disable Sign), so Sign is never sent to the wrong map.; #3 web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx:133-151 and WorkflowEditor.tsx:73: nothing links stage removal to remap, so items can end up on stages that no longer exist. When activating a workflow that drops or renames stages that have items, prompt for an old-to-new stage mapping (offer every removed stage with a target-stage select) and call remap as part of activation. Don't let activation finish with unmapped stages that still hold items.; #4 web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx:76,231-238: Activate depends on in-memory createdId, so a reload after Create loses the new workflow and the user can't activate it. Keep the draft workflow reachable. Either persist createdId (for example in the URL query) or list the team's non-active workflows so one can be chosen for activation.; #5 web/app/mindmaps/[key]/board/WaitingOnYou.tsx:311,374,437: the UI joins on memory_id while wp4.md T3/T5 pin node_id, so the T5 shape test would stay green if memory_id were dropped. Join on node_id.
Read first: see plan
Already finished tasks you build on: none

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. `web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx:157-195,289-330`: the remap prompt checks only the one map whose key the user types in. The workflow is team-wide, so other maps can still hold items on the removed stages. Activation is allowed once that one map's mappings are complete. `needsRemap` also covers removed stages that hold no items in the checked map, and an empty map key skips remap entirely. This doesn't meet "don't let activation finish with unmapped stages that still hold items."
2. `WorkflowSettingsClient.tsx:178-195`: activate runs before remap. If remap fails, the workflow is already active and items are left on stages that no longer exist. The UI only shows a banner. The accepted ordering and failure handling is not atomic.
3. `WorkflowSettingsClient.tsx:76-86,155-157`: the draft's stage names come from the `wfstages` URL param, not the server. A URL with only `?wf=<id>`, a malformed `wfstages`, or a hand-edited one makes every active stage look "removed". The target-stage select is then empty, so the user can't map items or activate. The draft workflow's real stages are never fetched.
4. `tests/integration/test_mindmap_workflow_web_ui_shapes.py:336-344`: the #1 "test" only checks that the API returns 400 and that the work-items list loads. It never exercises `page.tsx`, so removing the `400` branch there would not fail it. The legacy board rendering is not tested. The #5 assertion (`board[...]["node_id"] == row["node_id"]`) is also trivially true, because `_by_node` already keys on `node_id`, so it would stay green if `memory_id` came back in the UI.
5. `web/app/mindmaps/[key]/board/WaitingOnYou.tsx:61-64,142`: the other-map rows are filtered out as required. The empty state still says "Nothing is waiting on your sign-off" when the team has pending sign-offs on other maps. That is misleading, but minor.
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

