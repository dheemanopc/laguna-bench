You are reviewing a teammate's finished task. Do NOT edit any file. Task WP4-T4b: WorkflowEditor — pure stages/transitions editor (extracted from T4 to stay under 400 lines)
Acceptance: 'use client' presentational component; props {stages:string[], teamRoles:string[], workKinds:readonly string[], onStagesChange, onTransitionsChange} matching T4a's call site; renders ordered stages[] rows (name, is_initial, is_terminal; ordinal inferred) + transitions[] rows (from_stage select incl 'any', to_stage select, requires_reason, requires_signoff, signoff_min min1-when-signoff, signoff_roles multi-select from teamRoles, allowed_kinds multi-select from workKinds); add/remove rows; pure: no fetch, no writes, no router — keeps T4a under 400 lines; submission owned by T4a; npx tsc --noEmit from web/ is green
Package plan: `docs/feature/wp4.md` (DESIGN section). Changed files: web/app/teams/[team_id]/workflow/WorkflowEditor.tsx
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
