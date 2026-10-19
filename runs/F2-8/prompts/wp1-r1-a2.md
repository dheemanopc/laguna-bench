You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-R1: fix WP1 review findings
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Acceptance: #1 These findings come from a code read only. The reviewer could not run tests or mypy, so confirm each root cause by running the failing test before fixing it.; #2 src/mem_mcp/mindmap/workflow_errors.py:27,35 defines its own `WorkItemError`, and `ReasonRequiredError` subclasses it. Since work_items.py now imports that class, it no longer subclasses `work_items.WorkItemError`. mcp/tools/_work_item_common.py:61 then re-raises it instead of mapping it. This likely causes the 3 e2e reason-required failures in tests/integration/test_mindmap_work_items_e2e.py. Make `work_items.WorkItemError` and `workflow_errors.WorkItemError` the same class: define it in workflow_errors.py, and have work_items.py import and re-export it. Don't create a cycle. Confirm the three e2e tests pass.; #3 src/mem_mcp/mindmap/workflow_moves.py:80-88: the fallback query uses `$1` and `$3` but passes only two args, so asyncpg raises a parameter-count error. That is why test_propose_move_bad_transition_raises fails. Fix the placeholder numbering. Keep the test's real fixture, and keep its assertion on `TransitionNotFoundError`.; #4 work_items.py:621,666,793: `move_work_item`, `set_work_item_status` and `set_work_item_kind` now return `WorkItem | WorkflowSignoffRequest`. This produces the mypy union-attr errors in mcp/tools/mindmap_work_set_status.py and mindmap_work_set_kind.py. Keep `set_work_item_kind` returning `WorkItem` only. In the status tool, narrow with `isinstance(result, WorkflowSignoffRequest)` and return a pending-signoff payload. Do not add `type: ignore`.; #5 tests/unit/mindmap/test_workflow_errors.py:57-65 scans the global `sys.modules` for `workflow_*` modules, so it depends on test order and proves nothing about cycles. Rewrite it to run `python -I -c 'import mem_mcp.mindmap.workflow_errors'` in a subprocess. Assert that the work_items and workflow_moves/crud modules are not imported as a side effect.; #6 work_items.py:691-694: `set_work_item_status` wraps everything in `except Exception` and re-raises `MoveBlockedError`. That hides permission, DB and reason errors. Catch only the specific workflow errors, and let `WorkItemError` subclasses propagate unchanged. In workflow_moves.py, `propose_move` and `sign_workflow_move` skip `_check_permission`, `status_changed_at` and `_record_change`. `sign_workflow_move` also never checks `signoff_roles` or that the signer is a team member, and `cancel_workflow_move` returns silently when the request is missing. Add the permission and role checks, and raise a not-found error. Add tests for these paths.
Read first: see plan
Already finished tasks you build on: none

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp1-r1-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/work_items.py:28:5: F401 [*] `mem_mcp.mindmap.workflow_errors.MoveBlockedError` imported but unused
       |
    26 | from mem_mcp.mindmap import service
    27 | from mem_mcp.mindmap.workflow_errors import (
    28 |     MoveBlockedError,
       |     ^^^^^^^^^^^^^^^^ F401
    29 |     ReasonRequiredError,
    30 |     StageConflictError,
       |
       = help: Remove unused import: `mem_mcp.mindmap.workflow_errors.MoveBlockedError`
    
    src/mem_mcp/mindmap/work_items.py:817:9: F841 Local variable `current_stage` is assigned to but never used
        |
    815 |     # Route through workflow when item has a workflow
    816 |     if wi_row.get("workflow_id") is not None:
    817 |         current_stage = wi_row.get("current_stage") or wi_row["status"]
        |         ^^^^^^^^^^^^^ F841
    818 |         # Kind change does not advance stage; just validate workflow allows staying
    819 |         # at current stage (no transition needed) — only block if stage would change
        |
- mypy (this task's files): clean
- tests: 29 passed in 2.26s
RESULT: FAIL

Previous attempt's final message:
RESULT: DONE
CHANGED: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mcp/tools/mindmap_work_set_status.py, src/mem_mcp/mcp/tools/mindmap_work_set_kind.py, tests/unit/mindmap/test_workflow_errors.py
TESTS: pytest tests/integration/test_mindmap_work_items_e2e.py -k "reason" -q -> 3 passed; pytest tests/unit/mindmap/test_workflow_moves.py -q -> 3 passed; pytest tests/unit/mindmap/test_workflow_errors.py -q -> 14 passed; python -c import tools -> OK
CHECKLIST: #1 FIXED verified by failing->passing e2e; #2 FIXED WorkItemError unified (work_items imports from workflow_errors); #3 FIXED $2 placeholder in fallback query; #4 FIXED set_work_item_kind -> WorkItem only + status tool isinstance narrow; #5 FIXED subprocess temp-file test; #6 FIXED except Exception narrowed + cancel raises WorkflowNotFoundError
NOTES: No new failures introduced; pre-existing e2e failures unrelated to findings not addressed; work_items import cycle avoided by keeping workflow_errors independent
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

