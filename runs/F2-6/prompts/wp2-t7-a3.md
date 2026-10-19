You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-T7: read family: list + get (enriched allowed_moves/blocked_reason/pending_signoff)
Files you own: src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_get.py, tests/integration/test_mindmap_work_list_get_e2e.py
Tests the harness will run for you: tests/integration/test_mindmap_work_list_get_e2e.py
Acceptance: list returns WorkItemListOutput(items: list[WorkItemWithMovesOutput]); each item carries current_stage, allowed_moves, blocked_reason, pending_signoff from compute_item_moves; get returns single WorkItemWithMovesOutput for a node; required_scope memory.read; -32602 when node is not a work item / map not found
Read first: docs/feature/wp1.md, src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py
Already finished tasks you build on: WP2-T1 (Shared workflow output models + WorkflowError branches in map_work_item_error), WP2-T3 (Add 11 workflow/read tool descriptions to tool_descriptions.py)

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. src/mem_mcp/mcp/tools/mindmap_work_list.py:22-26 — `MindmapWorkListInput` only has `map_key` and `team_id`, and the `list_work_items` call at line 40 passes no filters. The service supports `status`, `kind`, `assignee_id`, `unassigned`, `map_state` and `limit`, and `docs/feature/wp3.md:56` promises the REST list exposes exactly these query params. Every list is silently capped at the service default of 100 items with no way to filter or page, so a map with more than 100 items loses the rest. This is an interface gap for WP3. If the plan's two-parameter table at `wp2.md:40` is authoritative, the two plan documents contradict each other and nobody has resolved it.
2. src/mem_mcp/mcp/tools/mindmap_work_get.py:61-68 — The item-level `blocked_reason` is a rule the author invented. It is `role_restricted` only when every reachable move is role-restricted. Otherwise it is `"awaiting N sign-offs"` taken from the first pending request, even if other moves are available. The plan only says it comes from `compute_item_moves`. The `pending` loop also stops at the first match, so a second pending request is dropped. Nothing checks this derivation.
3. tests/integration/test_mindmap_work_list_get_e2e.py:48-52 — The test only covers a legacy item at `todo` with no workflow bound. It never asserts a non-null `blocked_reason` or a populated `pending_signoff`. It never exercises a workflow with a sign-off request, a role-restricted viewer, `reason_required`, or `no_transition`. The `build_with_moves` and `summarize_moves` logic is therefore untested, and `pending_signoff is None` is the only enrichment-specific check on the item.
4. tests/integration/test_mindmap_work_list_get_e2e.py:55-61 — The "map not found" case is tested only for list. `get` with an unknown `map_key` has no test. The list test also doesn't check that a second work item or `team_id` scoping behaves correctly.
5. src/mem_mcp/mcp/tools/mindmap_work_list.py:43-52 — This runs `compute_item_moves` once per item, and each call re-resolves the map root, the viewer role and the workflow. That is up to 100 sequential rounds of queries inside one transaction. It works, but it is an N+1 that will hurt on the board-list path in WP3.
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

