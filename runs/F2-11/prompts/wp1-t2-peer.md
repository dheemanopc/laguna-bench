You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-T2: workflow_crud.py: create/activate/get/materialise_legacy/remap
Acceptance: create_team_workflow requires TEAM_WRITE_MEMORY (else WorkflowPermissionDeniedError); inserts team_workflows+stages+transitions atomically; is_active=false, version=1; activate_workflow requires TEAM_WRITE_MEMORY; sets one active per team (partial UNIQUE) and bumps version; materialise_legacy_workflow inserts _legacy (is_active=false) via INSERT ON CONFLICT (team_id,name) DO NOTHING; idempotent under concurrency; stages match WORK_STATUSES/TRANSITIONS; get_workflow returns active workflow (+ordered stages/transitions) or named id; remap_workflow_stages requires TEAM_WRITE_MEMORY; updates current_stage for mapped stages and returns count; all SQL has explicit tenant_id=$n + RLS; pytest -q passes after alembic upgrade head
Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/workflow_crud.py, tests/unit/mindmap/test_workflow_crud.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
