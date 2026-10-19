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
- ruff: clean
- mypy (this task's files): clean
- tests: 10 passed in 3.17s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 44:+    pytest.mark.skipif(not os.environ.get("MEM_MCP_TEST_DSN"), reason="needs test database"),
RESULT: FAIL

Previous attempt's final message:

CHANGED: tests/unit/mindmap/test_workflow_signoff.py
TESTS: `alembic upgrade head` -> ran with no errors (the test DB was missing the `team_workflows` table before this) ; `pytest tests/unit/mindmap/test_workflow_signoff.py -q` -> 10 passed in 3.95s ; `ruff check tests/unit/mindmap/test_workflow_signoff.py` -> All checks passed!
NOTES:
- There is no `TenantPair` fixture in the repo, so I reused the file-local `env` pattern from `test_workflow_moves.py`: one team with owner, two admins and a member, each assigned through `team_role_assignments`. The `signoff_roles` restriction is `("owner", "admin")`.
- Two acceptance items are covered indirectly: the `FOR UPDATE` check inspects the source of `_lock_request` rather than testing concurrency, and the SignoffRequiredError check only asserts the class is a distinct `WorkflowError` subtype. Neither `propose_move` nor the sign flow raises `SignoffRequiredError` here; a gated move returns a request, and an immediate-only entry point raises `MoveBlockedError`.
- `compute_item_moves` reports `remaining=0` and `signatory_count=0` when no request is pending, so I assert that rather than `remaining=signoff_min`.
- I did not run the full suite.
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

