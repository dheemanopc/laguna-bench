You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-T3: workflow_moves.py + work_items.py move/route + _resolve_workflow
Acceptance: move_work_item(conn,*,tenant_id,team_id,map_key,node_id,to_stage,reason,expected_stage,channel)->WorkItem in work_items.py resolves workflow via _resolve_workflow; _resolve_workflow returns item.workflow_id else team active else materialise_legacy_workflow; set_work_item_status/set_work_item_kind/mark_work_item route via move_work_item->propose_move (raising MoveBlockedError on disallowed moves) when workflow_id IS NOT NULL; unchanged when NULL; assign_work_item NOT routed; propose_move takes map_key+channel; FOR UPDATE; TransitionNotFoundError/reason/ReasonRequiredError; writes signoff_requests+history('signoff_requested') when requires_signoff WITHOUT advancing current_stage; else commits stage+history('stage'); sign_workflow_move: FOR UPDATE on request; owner/proposer excluded; UNIQUE prevents dup; commits at signoff_min; cancel only proposer/admin; cycle broken: work_items imports workflow_errors at top level, calls workflow_moves.propose_move via local import only
Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/workflow_moves.py, src/mem_mcp/mindmap/work_items.py, tests/unit/mindmap/test_workflow_moves.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
