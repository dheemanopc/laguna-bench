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

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp2-t3-a1 (harness-run)
- ruff: FAIL
    tests/unit/test_workflow_tool_descriptions.py:3:1: I001 [*] Import block is un-sorted or un-formatted
      |
    1 |   """Test that workflow tool descriptions are present, well-formed, and follow the required structure."""
    2 |   
    3 | / import re
    4 | | from mem_mcp.mcp.tool_descriptions import TOOL_DESCRIPTIONS
    5 | | 
    6 | | 
    7 | | REQUIRED_WORKFLOW_TOOLS = [
      | |_^ I001
    8 |       "mindmap_workflow_create",
    9 |       "mindmap_workflow_get",
      |
      = help: Organize imports
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 6 passed in 0.96s
RESULT: FAIL

Previous attempt's final message:
Perfect! All requirements are met. Let me create a final summary:

RESULT: DONE

CHANGED: src/mem_mcp/mcp/tool_descriptions.py, tests/unit/test_workflow_tool_descriptions.py

TESTS: 
- pytest tests/unit/test_workflow_tool_descriptions.py -q -> 6 passed in 0.95s
- Manual verification: All 11 descriptions valid (80-250 words, three-part structure with Call when/Do not call for/Examples)

CHECKLIST: none

NOTES: The file src/mem_mcp/mcp/tools/_work_item_common.py shows as modified in git status but was not intentionally edited in this task — it's a concurrent modification from another task in the work package. My task focused exclusively on tool_descriptions.py and the test file as specified.
Fix the failures (CHECKLIST each gate failure).
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

