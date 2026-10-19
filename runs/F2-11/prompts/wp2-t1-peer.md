You are reviewing a teammate's finished task. Do NOT edit any file. Task WP2-T1: Shared workflow output models + WorkflowError branches in map_work_item_error
Acceptance: map_work_item_error guard widened to isinstance(e,(WorkItemError,WorkflowError)); non-mapped exceptions re-raised unchanged; MoveBlockedError->JsonRpcError(-32602,code='move_blocked'); SignoffRequiredError->'signoff_required'; SignoffCompleteError->'signoff_complete'; exactly 13 shared output models defined: WorkflowStageOutput, WorkflowTransitionOutput, WorkflowOutput, WorkflowDetailOutput, WorkflowSignoffRequestOutput, ProposeMoveOutput, RemapWorkflowOutput, AllowedMoveOutput, WorkItemSignoffStateOutput, WorkItemWithMovesOutput, WorkItemListOutput, WorkItemHistoryEntryOutput, PendingSignoffOutput; WorkItemWithMovesOutput subclasses WorkItemOutput and adds current_stage, allowed_moves, blocked_reason, pending_signoff; ProposeMoveOutput has awaiting_signoff discriminator; unit test asserts the three WorkflowError mappings and that a ValueError propagates
Package plan: `docs/feature/wp2.md` (DESIGN section). Changed files: src/mem_mcp/mcp/tools/_work_item_common.py, tests/unit/test_workflow_error_mapping.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
