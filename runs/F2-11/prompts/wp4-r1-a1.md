You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-R1: fix WP4 review findings
Files you own: tests/integration/test_mindmap_workflow_web_ui_shapes.py, web/app/mindmaps/[key]/board/BoardContext.tsx, web/app/mindmaps/[key]/board/BoardView.tsx, web/app/mindmaps/[key]/board/ItemDetail.tsx, web/app/mindmaps/[key]/board/WaitingOnYou.tsx, web/app/mindmaps/[key]/board/page.tsx, web/app/teams/[team_id]/workflow/WorkflowEditor.tsx, web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx, web/app/teams/[team_id]/workflow/page.tsx
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Acceptance: #1 web/app/mindmaps/[key]/board/ItemDetail.tsx:92,246,285: needsReason reads the item-level blocked_reason, not the selected move's AllowedMoveOutput.blocked_reason. Use the selected move's data. Disable the Move button while a required reason is empty. Show a human-readable per-move blocked_reason (for example, 'a reason is required') and not the raw code 'blocked: reason_required'.; #2 web/app/mindmaps/[key]/board/ItemDetail.tsx:51-66 and BoardView.tsx:113: the open modal holds a stale copy of the board item. pending and toStage are seeded once, and request_id is read only from that stale copy. After a move, a sign-off, or router.refresh(), the modal keeps old sign-off counts and allowed moves. Re-derive the item from the refreshed items by id, or reset the state when the item changes.; #3 web/app/mindmaps/[key]/board/ItemDetail.tsx:73-85,99-122,157-175: write calls (move, sign-off, cancel) do not handle 401, so there is no login redirect. WaitingOnYou does this, and the plan requires it. Add the redirect to the write calls, and show an error for a failed history fetch instead of swallowing it.; #4 web/app/mindmaps/[key]/board/page.tsx:48,57,64-65: a 404 or error on the team workflow GET calls notFound(), so a team without an active workflow gets a 404 page instead of a board. Fall back to the legacy/default workflow or an empty state. Give non-401/404 failures a distinct error state. Replace the `as unknown as Parameters<...>` casts at lines 64-65 with shared types.; #5 tests/integration/test_mindmap_workflow_web_ui_shapes.py:246-254: the shape test is too weak. Assert the pending-signoffs row unconditionally, including request_id. Assert a no_transition item and a role_restricted item. Assert the move and signoff response shapes the UI reads (awaiting_signoff, committed, signed_count). Replace the broad `DELETE ... WHERE tenant_id` cleanup with scoped cleanup.
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

