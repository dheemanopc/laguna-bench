You are an engineer building ONE task of a feature in this repository. Other engineers work on other tasks in the
same working tree at the same time, so stay inside your files.
Feature goal: `docs/feature/00-goal.md` (read the GOAL and KEY DECISIONS sections only). Your package plan:
`docs/feature/wp5.md` (read its DESIGN section and your task).

TASK WP5-T2b: Integration e2e (web path parity) — same scenarios through client+session cookie, asserting identical DB/output/codes as WP5-T2a — tests/integration/test_mindmap_workflow_web_e2e.py
Files you own: tests/integration/test_mindmap_workflow_web_e2e.py
Tests the harness will run for you: tests/integration/test_mindmap_workflow_web_e2e.py
Acceptance: reuses conftest client fixture (TestClient, conftest.py:576) + user_with_workspace (conftest.py:375) + db_session; seeds a team owned by the workspace user + a second member identity with its own web_sessions row (session_hash=sha256(raw), expires_at) for signoff; POST/GET pass cookies={'mem_session': raw} (csrf handled by client defaults); skipif MEM_MCP_TEST_DSN unset; creates the workflow via the WP3 endpoint POST /teams/{team_id}/workflow (parity: web uses its own create endpoint; MCP side is WP5-T2a); board-list GET /mindmaps/{map_key}/work-items returns items carrying current_stage/allowed_moves/blocked_reason/pending_signoffs (+ team_id); propose(move) via POST .../work-items/{node_id}/move on a signoff-gated transition: response status='awaiting_signoff', request_id set, current_stage unchanged (DB asserted); sign via POST .../signoff with the signatory's session cookie → at signoff_min current_stage advances + history rows; owner/proposer-only signoffs keep it pending; no-signoff move via POST .../move commits (status='committed', current_stage advanced, no request row) — DB state matches WP5-T2a; set_status gate: WP3 has no web set_status/mark endpoint, so the gate is exercised via POST .../move — a disallowed transition returns 400 detail.code='move_blocked' and current_stage unchanged (mirrors MCP move_blocked); signoff_required surfaces as 400 detail.code='signoff_required' on POST .../move (via _http_from_jsonrpc, mindmaps.py:66-77); 401 without mem_session cookie on every endpoint; blocked reasons from board-list work-list output: reason_required/role_restricted/no_transition/'awaiting N sign-offs' with signoff_min/count/remaining; sign-upon-role-restriction rejects out-of-role signer (does not count); remap via POST /teams/{team_id}/workflow/remap: unmapped items keep current_stage and still appear in the board-list (unmapped-column contract); history rows keep stage_before/stage_after/workflow_id; pending-signoffs GET /teams/{team_id}/workflow/pending-signoffs returns eligible requests only; DB state + field names asserted to agree with WP5-T2a
Read first: src/mem_mcp/web/handlers/mindmaps.py:43-77,100-215, src/mem_mcp/web/handlers/workflows.py, src/mem_mcp/main.py:102,567, src/mem_mcp/mcp/tools/_work_item_common.py:56-195, docs/feature/wp3.md, docs/feature/wp4.md, docs/feature/wp5.md, tests/integration/test_mindmap_work_items_e2e.py, tests/integration/test_web_teams_api.py:42-52, tests/conftest.py, CONVENTIONS.md
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

