You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp4.md` (read its DESIGN section and your task).

TASK WP4-T5: Shape-contract test (WP3 only): assert board-list/workflow/pending-signoffs response shapes the UI reads
Files you own: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Acceptance: pg_pool + NoopAuditLogger/stub embedder like test_mindmap_work_items_e2e.py; UUID-suffixed team/workflow/item fixtures; seeds via raw asyncpg against 0048 schema (not MCP tools) so it depends on the HTTP layer only; asserts GET /mindmaps/{map_key}/work-items items carry {node_id, team_id, current_stage, allowed_moves, blocked_reason, pending_signoff} + top-level WorkListOutput.team_id; asserts transitions[] present; asserts GET /teams/{team_id}/workflow returns {workflow_id, name, is_active, version, stages[] ordered by ordinal, transitions[]}; asserts GET /teams/{team_id}/workflow/pending-signoffs rows carry node_id (+ from_stage, to_stage, reason, signoff_min, signatory_count, remaining) so T3 can join to board items; seeds reason_required / awaiting-signoffs / no_transition items and asserts those blocked_reason + pending_signoff shapes match the field names WP4-T1/T3 read
Read first: tests/integration/test_mindmap_work_items_e2e.py, tests/conftest.py, docs/feature/wp3.md, docs/feature/wp2.md, docs/feature/wp1.md, CONVENTIONS.md
Already finished tasks you build on: none

RETRY (attempt 3): your files already contain the previous attempt. The harness gate FAILED:
## Gate for wp4-t5-a2 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — 3 failed, 3 passed, 6 warnings in 2.60s
    >       assert body["team_id"] == str(env.team)
    E       KeyError: 'team_id'
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:246: KeyError
            assert body["workflow_id"] == str(env.workflow_id)
            assert body["is_active"] is True
            assert isinstance(body["name"], str)
            assert isinstance(body["version"], int)
            assert [s["name"] for s in stages] == _STAGES
            assert [s["ordinal"] for s in stages] == sorted(s["ordinal"] for s in stages)
                assert {"stage_id", "name", "ordinal", "is_initial", "is_terminal"} <= set(s)
            assert len(transitions) == 2
    >           assert {"from_stage", "to_stage", "requires_reason", "requires_signoff", "signoff_min",
    E           AssertionError: assert {'allowed_kin...f_roles', ...} <= {'allowed_kin...f_roles', ...}
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:311: AssertionError
            assert len(rows) == 1
    >           assert key in row, f"pending-signoffs row missing {key}"
    E           AssertionError: pending-signoffs row missing node_id
    E           assert 'node_id' in {'from_stage': 'review', 'memory_id': '1212b296-a703-49a9-80d6-1cb22531f891', 'proposer_tenant_id': 'f9095e12-1cf7-4a36-b664-e0368357e886', 'reason': 'ship it', ...}
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:326: AssertionError
    FAILED tests/integration/test_mindmap_workflow_web_ui_shapes.py::test_board_list_item_shape
RESULT: FAIL

Previous attempt's final message:
ecause `WorkflowTransitionOutput` carries `from_stage_id` and `to_stage_id` (UUIDs). The contract in `docs/feature/wp4.md` asks for `from_stage` and `to_stage` as stage names.
#3 NOT FIXED. `test_pending_signoffs_rows_join_to_board_items` fails because `PendingSignoffOutput` has `memory_id` and no `node_id`. The UI joins pending sign-offs to board items by `node_id`.
NOTES:
- All three failures are real mismatches between the WP3 backend and the WP4 contract. Fixing them means changing shared WP3 models and handlers (`_work_item_common.py`, the list, workflow and pending-signoffs tools, and `workflow_reads.py`). Those are outside my task, and other engineers are editing the same tree. Weakening the assertions would hide the mismatch, so I left them as they are.
- Decision needed: either WP3 adds `team_id` (top-level and per item), a `transitions[]` list on the board list, `from_stage`/`to_stage` names on workflow transitions, and `node_id` on pending-signoffs rows, or the WP4 contract changes to match the current shapes. The test passes once either side changes.
- The pending-signoffs response is wrapped as `{"requests": [...]}`, not a bare list. WP4-T3 should read `body.requests`.
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

