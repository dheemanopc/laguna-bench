You are reviewing a teammate's finished task. Do NOT edit any file. Task WP4-T5: Shape-contract test (WP3 only): assert board-list/workflow/pending-signoffs response shapes the UI reads
Acceptance: pg_pool + NoopAuditLogger/stub embedder like test_mindmap_work_items_e2e.py; UUID-suffixed team/workflow/item fixtures; seeds via raw asyncpg against 0048 schema (not MCP tools) so it depends on the HTTP layer only; asserts GET /mindmaps/{map_key}/work-items items carry {node_id, team_id, current_stage, allowed_moves, blocked_reason, pending_signoff} + top-level WorkListOutput.team_id; asserts transitions[] present; asserts GET /teams/{team_id}/workflow returns {workflow_id, name, is_active, version, stages[] ordered by ordinal, transitions[]}; asserts GET /teams/{team_id}/workflow/pending-signoffs rows carry node_id (+ from_stage, to_stage, reason, signoff_min, signatory_count, remaining) so T3 can join to board items; seeds reason_required / awaiting-signoffs / no_transition items and asserts those blocked_reason + pending_signoff shapes match the field names WP4-T1/T3 read
Package plan: `docs/feature/wp4.md` (DESIGN section). Changed files: tests/integration/test_mindmap_workflow_web_ui_shapes.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
