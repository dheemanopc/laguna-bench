You are reviewing a teammate's finished task. Do NOT edit any file. Task WP2-T7: read family: list + get (enriched allowed_moves/blocked_reason/pending_signoff)
Acceptance: list returns WorkItemListOutput(items: list[WorkItemWithMovesOutput]); each item carries current_stage, allowed_moves, blocked_reason, pending_signoff from compute_item_moves; get returns single WorkItemWithMovesOutput for a node; required_scope memory.read; -32602 when node is not a work item / map not found
Package plan: `docs/feature/wp2.md` (DESIGN section). Changed files: src/mem_mcp/mcp/tools/mindmap_work_list.py, src/mem_mcp/mcp/tools/mindmap_work_get.py, tests/integration/test_mindmap_work_list_get_e2e.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
