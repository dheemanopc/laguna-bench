You are reviewing a teammate's finished task. Do NOT edit any file. Task WP4-T3: WaitingOnYou panel (replaces T1 stub): pending-signoffs rows, node_id join to board items, inline Sign buttons
Acceptance: implements WaitingOnYouProps from T1's stub; collapsible panel below board; GET /teams/{team_id}/workflow/pending-signoffs (team_id from WorkListOutput.team_id); each row looked up to board items by node_id (rows carry node_id, pinned + asserted by WP4-T5); row shows from_stage→to_stage, item title snippet, reason, signoff_count/signoff_min, remaining; inline Sign → POST /mindmaps/{map_key}/work-items/{node_id}/signoff {request_id} via csrfHeaders; 'committed'→bumpRefresh, 'awaiting_signoff'→update counts; signatory is session-resolved (never a UI field); 401→login redirect, 400 banner (signoff_complete); bumps boardRefreshKey; npx tsc --noEmit from web/ is green
Package plan: `docs/feature/wp4.md` (DESIGN section). Changed files: web/app/mindmaps/[key]/board/WaitingOnYou.tsx
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
