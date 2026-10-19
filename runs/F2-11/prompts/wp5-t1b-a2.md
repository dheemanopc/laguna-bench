You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-T1b: Domain signoff / reads / error-code unit tests (propose/sign/cancel + compute_item_moves + list_pending_signoffs + WorkflowError types) — tests/unit/mindmap/test_workflow_signoff.py
Files you own: tests/unit/mindmap/test_workflow_signoff.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_signoff.py
Acceptance: pg_pool + tenant_tx + NoopAuditLogger/stub embed + TenantPair(owner=tenant_a/signatory=tenant_b) fixtures; seeds a signoff_roles-restricted transition + two distinct identities via team_role_assignments; skipif MEM_MCP_TEST_DSN unset; propose_move on a no-signoff transition commits current_stage + appends history('stage' with stage_before/stage_after/workflow_id) in one transaction; propose_move on a signoff-gated transition writes workflow_signoff_requests(status='pending') + history('signoff_requested') and does NOT advance current_stage; returns the request; sign_workflow_move uses FOR UPDATE; commits only at signoff_min distinct ELIGIBLE signatories (signatory != assignee_id and != proposer_tenant_id; signoff_roles applied) and appends 'stage' + 'signoff_approved' history + sets request.status='committed'; owner/proposer signs do NOT decrement the count (item stays pending); cancel_workflow_move only succeeds for proposer or team admin and sets request.status='cancelled'; compute_item_moves returns blocked_reason in {None, reason_required, no_transition, role_restricted, 'awaiting N sign-offs'} with signoff_min/signoff_count/remaining/eligible_to_sign; an unmapped current_stage yields no_transition with no allowed_moves (unmapped-column contract); list_pending_signoffs_for_user returns only requests the signatory is eligible for (excludes owner/proposer, respects signoff_roles) with from_stage/to_stage/signoff_min/signoff_count/remaining; asserts the exception TYPE that WP2 maps: propose_move raises SignoffRequiredError (-> signoff_required), disallowed legacy move raises MoveBlockedError (-> move_blocked), blank-reason raises ReasonRequiredError (-> reason_required); verifies the type, not just the message
Read first: src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/work_items.py:140,448, src/mem_mcp/mcp/tools/_work_item_common.py:56-195, docs/feature/wp1.md, docs/feature/wp2.md, tests/integration/test_mindmap_work_items_e2e.py, tests/conftest.py, CONVENTIONS.md
Already finished tasks you build on: none

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp5-t1b-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_signoff.py:3:1: I001 [*] Import block is un-sorted or un-formatted
       |
     1 |   """Tests for workflow_moves (propose/sign/cancel) + workflow_reads + error types."""
     2 |   
     3 | / from __future__ import annotations
     4 | | 
     5 | | import os
     6 | | from typing import Any
     7 | | from uuid import UUID, uuid4
     8 | | 
     9 | | import asyncpg
    10 | | import pytest
    11 | | 
    12 | | from mem_mcp.db import tenant_tx
    13 | | from mem_mcp.mindmap import work_items, workflow_moves, workflow_reads
    14 | | from mem_mcp.mindmap.workflow_crud import create_team_workflow, activate_workflow, materialise_legacy_workflow
    15 | | from mem_mcp.mindmap.workflow_errors import (
    16 | |     MoveBlockedError,
    17 | |     ReasonRequiredError,
    18 | |     SignoffNotAllowedError,
- mypy (this task's files): clean
- tests: 11 passed in 2.25s
RESULT: FAIL

Previous attempt's final message:
RESULT: DONE
CHANGED: tests/unit/mindmap/test_workflow_signoff.py
TESTS: pytest tests/unit/mindmap/test_workflow_signoff.py -q -> 11 passed in 2.55s
NOTES: none
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

