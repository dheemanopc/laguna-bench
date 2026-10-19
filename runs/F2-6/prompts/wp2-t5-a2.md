You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-T5: propose_move tool (WorkItem | WorkflowSignoffRequest union)
Files you own: src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py, tests/integration/test_mindmap_workflow_propose_move_e2e.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_propose_move_e2e.py
Acceptance: calls work_items.move_work_item; ProposeMoveOutput.awaiting_signoff discriminates WorkItem vs WorkflowSignoffRequest; no-signoff move: awaiting_signoff=false, current_stage==to_stage; signoff-required move: awaiting_signoff=true, request_id set, current_stage unchanged; MoveBlockedError -> -32602 code='move_blocked'
Read first: docs/feature/wp1.md, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/_work_item_common.py
Already finished tasks you build on: WP2-T1 (Shared workflow output models + WorkflowError branches in map_work_item_error), WP2-T2 (Widen except clauses in existing work tools to catch WorkflowError), WP2-T3 (Add 11 workflow/read tool descriptions to tool_descriptions.py)

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. `src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:62`: The tool never discriminates `WorkItem | WorkflowSignoffRequest`, which the plan (wp2.md:49-52) and the acceptance require. `move_work_item` still returns only `WorkItem` (`work_items.py:968`), and no WP1 widening is in the diff. The tool guesses `awaiting_signoff` from `item.current_stage == inp.to_stage`. If an item is already in `to_stage`, or the stage changes concurrently, the guess can be wrong.
2. `src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:67-85`: After the move, the tool re-queries `workflow_signoff_requests` for the latest pending row matching `to_stage`. It can therefore return the `request_id` of an older pending request instead of the one this call created. It also calls the private `workflow_moves._find_transition` and reads the table directly, which bypasses the service layer that `CONVENTIONS.md` requires. Both are workarounds for the missing union return.
3. `tests/integration/test_mindmap_workflow_propose_move_e2e.py:232-248`: The signoff test checks `signoff_min` but not `signoff_roles` or `from_stage`. It builds its SQL by f-string interpolation. Nothing tests a sequence that would expose finding 2, such as a second propose or an existing pending request.
4. `tests/integration/test_mindmap_workflow_propose_move_e2e.py:251-258`: `test_move_blocked_maps` moves `review` → `review` with no stated reason that `MoveBlockedError` is the result. I couldn't run it (the sandbox blocked pytest), so I can't confirm it is blocked rather than `invalid_transition`. The plan also lists `reason_required`, `invalid_transition`, `signoff_required` and `role_restricted` (-32000) errors, and `expected_stage` race handling. None of these has a test.
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

