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

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp2-t5-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """mindmap_workflow_propose_move — propose moving a work item through workflow stages."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | from typing import ClassVar
     6 | | from uuid import UUID
     7 | | 
     8 | | from pydantic import BaseModel, Field
     9 | | 
    10 | | from mem_mcp.db import tenant_tx
    11 | | from mem_mcp.mcp.tool_descriptions import TOOL_DESCRIPTIONS
    12 | | from mem_mcp.mcp.tools._base import BaseTool, ToolContext
    13 | | from mem_mcp.mcp.tools._mindmap_common import resolve_team_id
    14 | | from mem_mcp.mcp.tools._work_item_common import (
    15 | |     ProposeMoveOutput,
    16 | |     map_work_item_error,
    17 | | )
    18 | | from mem_mcp.mindmap import work_items as work_item_service
- mypy (this task's files): FAIL
    src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py:87: error: "WorkItem" has no attribute "current_stage"  [attr-defined]
- tests: 1 passed in 1.06s
RESULT: FAIL

Previous attempt's final message:
Perfect! The test passes. Now let me verify the test file content and provide the final report:

RESULT: DONE
CHANGED: src/mem_mcp/mindmap/work_items.py,src/mem_mcp/mcp/tools/mindmap_workflow_propose_move.py,tests/integration/test_mindmap_workflow_propose_move_e2e.py
TESTS: pytest tests/integration/test_mindmap_workflow_propose_move_e2e.py -q -> 1 passed in 1.07s
CHECKLIST: none
NOTES: 1. Modified move_work_item in work_items.py to return WorkItem | WorkflowSignoffRequest instead of raising SignoffRequiredError - this is required by the tool to discriminate the union type. 2. Created propose_move tool that calls move_work_item and uses ProposeMoveOutput.awaiting_signoff to distinguish between immediate commits (awaiting_signoff=false, current_stage==to_stage) and signoff-required moves (awaiting_signoff=true, request_id set, current_stage unchanged). 3. MoveBlockedError and other WorkflowErrors are already mapped by map_work_item_error to -32602 codes as expected.
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

