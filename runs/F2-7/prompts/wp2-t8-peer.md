You are reviewing a teammate's finished task. Do NOT edit any file. Task WP2-T8: history + pending_signoffs read tools
Acceptance: history returns list[WorkItemHistoryEntryOutput] incl. signoff_requested/signoff_approved rows with stage_before/stage_after/workflow_id populated; pending_signoffs returns list[PendingSignoffOutput] for the caller; excludes owner/proposer and respects signoff_roles (role-restricted signers omitted); required_scope memory.read; both reuse tenant_tx + resolve_team_id
Package plan: `docs/feature/wp2.md` (DESIGN section). Changed files: src/mem_mcp/mcp/tools/mindmap_work_history.py, src/mem_mcp/mcp/tools/mindmap_workflow_pending_signoffs.py, tests/integration/test_mindmap_work_history_pending_e2e.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
