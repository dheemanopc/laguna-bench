You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp2.md` (read its DESIGN section and your task).

TASK WP2-T3: Add 11 workflow/read tool descriptions to tool_descriptions.py
Files you own: src/mem_mcp/mcp/tool_descriptions.py, tests/unit/test_workflow_tool_descriptions.py
Tests the harness will run for you: tests/unit/test_workflow_tool_descriptions.py
Acceptance: 11 keys present: mindmap_workflow_create, mindmap_workflow_get, mindmap_workflow_activate, mindmap_workflow_propose_move, mindmap_workflow_signoff, mindmap_workflow_cancel_move, mindmap_workflow_remap, mindmap_workflow_pending_signoffs, mindmap_work_list, mindmap_work_get, mindmap_work_history; each 80-250 words, three-part call/anti-trigger/example structure, non-empty
Read first: src/mem_mcp/mcp/tool_descriptions.py, docs/feature/wp0.md
Already finished tasks you build on: none

A reviewer found issues in your finished work; fix them (CHECKLIST each):
1. `src/mem_mcp/mcp/tool_descriptions.py` (`mindmap_workflow_remap`, Inputs line): The description says it "Returns a summary of how many items were remapped per stage". The plan returns `RemapWorkflowOutput`, which has only `updated_count: int`. There is no per-stage breakdown. An LLM client would expect fields that don't exist.
2. `src/mem_mcp/mcp/tool_descriptions.py` (`mindmap_workflow_remap`, Do-not-call line): The claim "remap bypasses per-item review and sign-offs" isn't in the plan or the T1 models. No acceptance criterion or WP1 behaviour supports it.
3. `src/mem_mcp/mcp/tool_descriptions.py` (`mindmap_workflow_cancel_move`, Inputs line): "existing sign-offs on the request are discarded" is invented. The plan only says cancel sets `status='cancelled'`. Remove it or confirm it against WP1.
4. `tests/unit/test_workflow_tool_descriptions.py`: The structure test only checks that the three marker strings appear in order, and that the tool name appears after "Examples:". It never checks that error codes, inputs or outputs match the plan. That is how findings 1–3 got through.

I did not run the test file or the word-count check; the Bash calls were blocked. I read the diff and compared it with the plan only. I did not check the item field list in `mindmap_work_list` ("node_id, title, kind, status, assignee, ...") against `WorkItemOutput`.
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

