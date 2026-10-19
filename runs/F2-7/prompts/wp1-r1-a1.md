You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp1.md` (read its DESIGN section and your task).

TASK WP1-R1: fix WP1 review findings
Files you own: src/mem_mcp/mindmap/work_items.py, src/mem_mcp/mindmap/workflow_crud.py, src/mem_mcp/mindmap/workflow_errors.py, src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Tests the harness will run for you: tests/unit/mindmap/test_workflow_crud.py, tests/unit/mindmap/test_workflow_errors.py, tests/unit/mindmap/test_workflow_moves.py, tests/unit/mindmap/test_workflow_reads.py
Acceptance: #1 workflow_reads.py:178 and :272: `viewing_tenant_id in trans.signoff_roles` and `signatory_tenant_id not in signoff_roles` compare a tenant UUID with role names. This makes eligible_to_sign wrong and list_pending_signoffs_for_user return nothing. Resolve the viewer's team role with get_team_role, as workflow_moves.py:384 does. Make compute_item_moves set role_restricted and apply requires_reason. Add tests for a role-restricted transition and for pending sign-offs.; #2 workflow_reads.py:208-260: the pending-signoffs query is missing `wi.root_memory_id`. It does no team-role or visibility check on the caller. Its stage join (`OR wt.from_stage_id IS NULL`) can match several transitions and return the wrong signoff_min. Join on the exact transition (the request's transition_id if stored, else an exact from/to match) and add a test.; #3 workflow_moves.py:574-621: cancel_workflow_move has no FOR UPDATE and no check that the request is still `pending`, so it can cancel a request that was already committed. It also writes no history or event row. sign_workflow_move (:315) skips _load_map and the team visibility/role check, so any tenant with a request id can sign. Fix both and add tests.; #4 Typing and lint rules: remove `# type: ignore[import-untyped]` at workflow_moves.py:13 and in test_workflow_moves.py:12. Remove `conn: Any` in workflow_reads.py:48 and :208. Fix the mypy failure at workflow_crud.py:17 properly without touching the mypy config, using the same typing as the other mindmap modules or a small connection Protocol or alias. Type the workflow_moves.py:53 and :303 returns as WorkItem | WorkflowSignoffRequest and WorkItem | None, not object.; #5 workflow_crud.py:92 and :135 raise bare ValueError. Use WorkflowError subclasses from workflow_errors.py. Remove the unused KindNotAllowedError or use it. workflow_crud.py:346 sets `created_by=team_id`, which is wrong. Use the acting user or tenant id.
Read first: see plan
Already finished tasks you build on: none

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

