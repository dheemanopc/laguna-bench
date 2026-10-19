You are reviewing a teammate's finished task. Do NOT edit any file. Task WP3-T2: Map board + item-action endpoints: work-items list/get/history/move/signoff in make_mindmaps_router
Acceptance: 5 endpoints added to make_mindmaps_router: GET /mindmaps/{map_key}/work-items, GET .../{node_id}, GET .../{node_id}/history, POST .../{node_id}/move, POST .../{node_id}/signoff; board-list GET maps query params (status, kind, assignee_id, unassigned, map_state, limit) + map_key path into MindmapWorkListInput(team_id=None); GET (board item) and POST (move/signoff) build MindmapWorkGetInput/WorkflowProposeMoveInput/WorkflowSignoffInput from path + body, signatory/identity from session ctx; move -> MindmapWorkflowProposeMoveTool, signoff -> MindmapWorkflowSignoffTool, list -> MindmapWorkListTool, get -> MindmapWorkGetTool, history -> MindmapWorkHistoryTool; board-list and get responses carry per-item current_stage, allowed_moves, blocked_reason, pending_signoffs (from WP2 WorkListItemOutput); move_blocked, signoff_required and signoff_complete JsonRpcErrors return 400 with the code in detail; no-session returns 401; existing tests/unit/test_web_mindmaps_router.py still passes (endpoints only added, no existing behaviour changed)
Package plan: `docs/feature/wp3.md` (DESIGN section). Changed files: src/mem_mcp/web/handlers/mindmaps.py, tests/unit/test_web_mindmaps_work_items_router.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
