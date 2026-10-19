You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-T1: Shared workflow exception hierarchy in workflow_errors.py
Files you own: src/mem_mcp/mindmap/workflow_errors.py, tests/unit/mindmap/test_workflow_errors.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_errors.py
Acceptance: workflow_errors.py defines WorkflowError(Exception) base + MoveBlockedError/ReasonRequiredError-reuse/SignoffRequiredError/SignoffCompleteError and the CRUD/signoff exceptions with their documented attrs; ReasonRequiredError is reused from mindmap.work_items (same class object) so legacy + workflow paths share one reason gate; DB-free pytest passes; importing workflow_errors has no runtime deps on work_items/workflow_* modules (no import cycle); lint_tenant_scope / ruff / mypy clean on the new module
Read first: src/mem_mcp/mindmap/work_items.py:55-180, src/mem_mcp/mcp/tools/_work_item_common.py:56-195, CONVENTIONS.md
Already finished tasks you build on: none

RETRY (attempt 2): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp1-t1-a1 (harness-run)
- ruff: FAIL
    src/mem_mcp/mindmap/workflow_errors.py:3:64: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
      |
    1 | """Shared workflow exception hierarchy.
    2 | 
    3 | This module defines a set of exception classes used by the mind‑map workflow
      |                                                                ^ RUF002
    4 | service.  The hierarchy mirrors the `work_items` exceptions but is independent
    5 | so that the work‑item and workflow layers can import each other without creating
      |
    
    src/mem_mcp/mindmap/workflow_errors.py:5:17: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
      |
    3 | This module defines a set of exception classes used by the mind‑map workflow
    4 | service.  The hierarchy mirrors the `work_items` exceptions but is independent
    5 | so that the work‑item and workflow layers can import each other without creating
      |                 ^ RUF002
    6 | an import cycle.
      |
    
    src/mem_mcp/mindmap/workflow_errors.py:9:59: RUF002 Docstring contains ambiguous `‑` (NON-BREAKING HYPHEN). Did you mean `-` (HYPHEN-MINUS)?
- mypy (this task's files): clean
- tests: 13 passed in 1.13s
RESULT: FAIL

Previous attempt's final message:
RESULT: DONE
CHANGED: src/mem_mcp/mindmap/workflow_errors.py, tests/unit/mindmap/test_workflow_errors.py
TESTS: pytest tests/unit/mindmap/test_workflow_errors.py -q -> 13 passed in 1.09s
CHECKLIST:
NOTES: Added full workflow exception hierarchy with shared ReasonRequiredError and comprehensive DB‑free unit tests.
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

