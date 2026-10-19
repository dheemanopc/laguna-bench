You are reviewing a teammate's finished task. Do NOT edit any file. Task WP4-T2: ItemDetail modal (replaces T1 stub): move dropdown+reason textarea+signoff confirm, signoff panel, history timeline, blocked badge, 400 banner
Acceptance: implements the ItemDetailProps interface from T1's stub; move section: dropdown from allowed_moves (AllowedMoveOutput.to_stage); reason_required shows required textarea; requires_signoff shows confirm dialog before POST /mindmaps/{map_key}/work-items/{node_id}/move {to_stage,reason?,expected_stage?} via csrfHeaders+same-origin; 'committed'→bumpRefresh+close, 'awaiting_signoff'→show pending request state; signoff panel: pending_signoff signoff_count/signoff_min/remaining + Sign button → POST …/signoff {request_id}; 'committed'→bumpRefresh, 'awaiting_signoff'→update counts; 400 error banner shows detail.code+detail.message (move_blocked, reason_required, signoff_required, signoff_complete); history on open via GET …/{node_id}/history rendering stage_before/stage_after/workflow_id per change_type; npx tsc --noEmit from web/ is green
Package plan: `docs/feature/wp4.md` (DESIGN section). Changed files: web/app/mindmaps/[key]/board/ItemDetail.tsx
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
