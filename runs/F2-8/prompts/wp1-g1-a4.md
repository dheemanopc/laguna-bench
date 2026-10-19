You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-G1: fix WP1 gate failures
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Acceptance: #1 The package milestone gate failed (full suite / mypy / ruff / web). Fix these:
## Milestone gate wp1 (harness-run)
- ruff: [*] 1 fixable with the `--fix` option.
- mypy: Found 17 errors in 3 files (checked 187 source files)
    src/mem_mcp/mcp/tools/_work_item_common.py:14: error: Module "mem_mcp.mindmap.work_items" does not explicitly export attribute "ReasonRequiredError"  [attr-defined]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:82: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "map_state"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:83: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "kind"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:85: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "assignee_id"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:86: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "title"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:87: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "created_by"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:88: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "created_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:89: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "updated_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_status.py:90: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "status_changed_at"  [union-attr]
    src/mem_mcp/mcp/tools/mindmap_work_set_kind.py:80: error: Item "WorkflowSignoffRequest" of "WorkItem | WorkflowSignoffRequest" has no attribute "map_state"  [union-attr]
- alembic heads: 1
- full suite:  23 failed, 1441 passed, 31 skipped, 94 warnings, 16 errors in 45.13s
- NEW failures vs known red: 5
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_blocked_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_cancelled_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_reason_blank_rejected
    tests/unit/mindmap/test_workflow_errors.py::test_no_cycle_imports
    tests/unit/mindmap/test_workflow_moves.py::test_propose_move_bad_transition_raises
- web: no changes
RESULT: FAIL

Read first: see plan
Already finished tasks you build on: none

RETRY with guidance from the delivery lead:
Two things remain.
1) ruff F401 in tests/unit/mindmap/test_workflow_errors.py:61. The in-process sys.modules check I asked you to replace is still there. Rewrite test_no_cycle_imports to run `subprocess.run([sys.executable, '-I', '-c', "import sys, mem_mcp.mindmap.workflow_errors; assert not any(m.startswith('mem_mcp.mindmap.work') and m != 'mem_mcp.mindmap.workflow_errors' for m in sys.modules)"], check=True)`. That removes the unused import. Do not add a noqa.
2) The 3 e2e reason-required failures are in scope. They are the regression from moving ReasonRequiredError. `workflow_errors.WorkItemError` must be the same class as `work_items.WorkItemError`: define it once in workflow_errors.py and re-export it from work_items.py. Remove the duplicate class and the mid-file import. Then run tests/integration/test_mindmap_work_items_e2e.py and make sure the 3 tests pass.
Run ruff, mypy and the full pytest suite.
Last gate output:
## Gate for wp1-g1-a3 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_errors.py:61:12: F401 [*] `mem_mcp.mindmap.workflow_errors` imported but unused
       |
    59 |     import sys
    60 |     before = {n for n in sys.modules if "workflow_" in n}
    61 |     import mem_mcp.mindmap.workflow_errors
       |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ F401
    62 |     after = {n for n in sys.modules if "workflow_" in n and n != "mem_mcp.mindmap.workflow_errors"}
    63 |     new = after - before
       |
       = help: Remove unused import: `mem_mcp.mindmap.workflow_errors`
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 29 passed in 2.04s
RESULT: FAIL

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

