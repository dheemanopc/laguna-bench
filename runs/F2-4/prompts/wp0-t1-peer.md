You are reviewing a teammate's finished task. Do NOT edit any file. Task WP0-T1: Migration 0048 + schema test: workflow tables, work_items/work_item_history extensions
Acceptance: alembic upgrade head applies 0048 cleanly (down_revision=0047_work_item_history_rls_fix); 5 new tables (team_workflows, workflow_stages, workflow_transitions, workflow_signoff_requests, workflow_signoffs) exist with RLS enabled + tenant_id=safe_current_tenant_id() SELECT/INSERT policies and per-table grants (stages/transitions/signoffs: SELECT+INSERT only); work_items has nullable workflow_id→team_workflows (NO ACTION) + current_stage + work_items_tenant_team_current_stage_idx; work_item_history has stage_before/stage_after/workflow_id and change_type CHECK includes stage/signoff_requested/signoff_approved; deleting a team_workflows row is blocked (NO ACTION FK from work_items.workflow_id and work_item_history.workflow_id) once items or history reference it (R4)
Package plan: `docs/feature/wp0.md` (DESIGN section). Changed files: alembic/versions/0048_2026_10_17_team_workflows.py, tests/unit/test_migration_0048_workflow_schema.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
