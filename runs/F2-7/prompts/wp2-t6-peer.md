You are reviewing a teammate's finished task. Do NOT edit any file. Task WP2-T6: signoff + cancel + remap tools
Acceptance: signoff commits stage when distinct signatories reach signoff_min; owner/proposer excluded from count while role restriction still applies; cancel only allowed for proposer or team admin; sets request status='cancelled'; remap returns RemapWorkflowOutput.updated_count (int); unmapped items keep their stage; pattern: tenant_tx + resolve_team_id + map_work_item_error + audit; integration test asserts DB state + output + -32602 codes
Package plan: `docs/feature/wp2.md` (DESIGN section). Changed files: src/mem_mcp/mcp/tools/mindmap_workflow_signoff.py, src/mem_mcp/mcp/tools/mindmap_workflow_cancel_move.py, src/mem_mcp/mcp/tools/mindmap_workflow_remap.py, tests/integration/test_mindmap_workflow_signoff_remap_e2e.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
