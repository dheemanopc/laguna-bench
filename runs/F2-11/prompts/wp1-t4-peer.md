You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-T4: workflow_reads.py: compute_item_moves + list_pending_signoffs_for_user
Acceptance: AllowedMove(to_stage,transition_id,blocked_reason,request_id,signatory_count,signoff_min,remaining,eligible_to_sign) and PendingSignoff dataclasses defined; compute_item_moves(tenant_id,team_id,map_key,node_id,viewing_tenant_id) returns per-candidate-to_stage blocked_reason in {None,reason_required,awaiting N sign-offs,role_restricted,no_transition} plus pending signoff state; eligible_to_sign reflects owner/proposer exclusion + signoff_roles for the viewer; list_pending_signoffs_for_user(team_id,signatory_tenant_id) returns pending requests the user can sign (excludes owner/proposer, respects signoff_roles); DB-backed pytest -q passes after alembic upgrade head
Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/workflow_reads.py, tests/unit/mindmap/test_workflow_reads.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
