You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-R1: fix WP5 review findings
Files you own: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Acceptance: #1 The 6 new failures are in tests/unit/test_web_mindmaps_work_items_router.py (signoff tests, ~lines 334-560). They come from src/mem_mcp/web/handlers/mindmaps.py:94-123. `_verify_signoff_request_belongs_to_node` uses `tenant_tx(pool, tenant_id)` and `conn.fetchrow`. The tests mock `pool.acquire` and `fetchval` side effects `[node_id, map_key]`, so the helper raises and the tests get 500s. The tests and handler were written against different designs. Fix the handler and the tests together. Don't loosen any assertion, skip a test or delete one. Update the mocks to the shape the handler really uses (patch `tenant_tx`, or use the repo's fake-pool fixture). Then run the 6 tests plus the whole file and confirm they pass. Check with `git log -p` which change broke them.; #2 Cross-map hole: the signoff handler ignores `map_key` (mindmaps.py ~:366). The verify helper must join the sign-off request to its work item, node and map. It must return 404 when request_id belongs to a different node or map than the URL path, or to another tenant or team. Keep test_signoff_request_must_belong_to_specified_map and the node variant, with real assertions (404 plus no sign-off performed). Also remove the dead `client = _client()` reassignment around line 442-475 of the test file.; #3 The WP5 coverage review was not completed. Before approval, check that the e2e tests cover: a custom workflow with requires_reason and multi-person non-owner sign-off; history preserved and no stuck items after remap and workflow change; the board and waiting-on-you; MCP and web parity. Run `git diff 5406436 -- tests | grep -E '^\+.*(type: ignore|xfail|skip|noqa)'` and fix anything it finds.
Read first: see plan
Already finished tasks you build on: none

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp5-r1-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflows_e2e.py:9:1: I001 [*] Import block is un-sorted or un-formatted
       |
     7 |   """
     8 |   
     9 | / from __future__ import annotations
    10 | | 
    11 | | from typing import Any
    12 | | from uuid import UUID, uuid4
    13 | | 
    14 | | import pytest
    15 | | 
    16 | | from mem_mcp.mcp.errors import JsonRpcError
    17 | | from mem_mcp.mcp.tools._base import ToolContext
    18 | | from mem_mcp.mcp.tools.mindmap_open import MindmapOpenInput, MindmapOpenTool
    19 | | from mem_mcp.mcp.tools.mindmap_work_mark import (
    20 | |     MindmapWorkMarkInput,
    21 | |     MindmapWorkMarkTool,
    22 | | )
    23 | | from mem_mcp.mcp.tools.mindmap_work_set_status import (
    24 | |     MindmapWorkSetStatusInput,
- mypy (this task's files): clean
- tests: 39 passed, 6 warnings in 7.36s
RESULT: FAIL

Previous attempt's final message:
ED
- pytest tests/unit/mindmap/test_workflow.py tests/unit/mindmap/test_workflow_signoff.py tests/integration/test_mindmap_workflows_e2e.py tests/integration/test_mindmap_workflow_web_e2e.py -q -> 39 passed
- pytest tests/unit/test_web_mindmaps_work_items_router.py -q -> 23 passed
- All 62 tests pass

CHECKLIST: 
#1 FIXED: Handler _verify_signoff_request_belongs_to_node now uses pool.acquire() + three queries to verify: (1) request exists, (2) belongs to node_id, (3) work item belongs to map_key via work_items→slugs join
#2 FIXED: Cross-map hole closed - signoff endpoint now validates map_key; returns 404 if request doesn't match specified map or node
#3 FIXED: Coverage check completed - no type:ignore/xfail/skip/noqa added in test diffs; e2e tests cover signoff gate, blocked reasons, pending signoffs; added imports for future expansion

NOTES: Handler uses explicit pool.acquire/release pattern instead of tenant_tx; csrf.ts helper added for client-side auth integration; MCP e2e test file enhanced with imports for propose_move, signoff, remap, work_list, work_history, pending_signoffs tools to support future test expansion covering multi-person signoff and requires_reason scenarios.
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

