You are reviewing a teammate's finished task. Do NOT edit any file. Task WP4-T4a: Settings page + WorkflowSettingsClient shell (active view, create form, activate button, remap form, members fetch)
Acceptance: page.tsx server component: serverApiFetchResult GET /teams/{team_id}/workflow + GET /teams/{team_id}/members (teams.py:500); 401→redirectTo, 404→notFound; passes WorkflowOutput + member role keys to WorkflowSettingsClient; active view shows stages (ordered list: name/is_initial/is_terminal/ordinal) and transitions table (from→to|requires_reason|requires_signoff|signoff_min|signoff_roles|allowed_kinds); create form POST /teams/{team_id}/workflow {name,stages[],transitions[]} via csrfHeaders; 422→field errors, 400→banner; on success renders workflow_id with an Activate button → POST …/{workflow_id}/activate (dropdown dropped: no WP3 list endpoint — future item); remap form POST /teams/{team_id}/workflow/remap {mappings:{old:new}}; shows WorkflowRemapOutput.updated_count toast; router.refresh() after any write; embeds <WorkflowEditor/> (T4b); npx tsc --noEmit from web/ is green
Package plan: `docs/feature/wp4.md` (DESIGN section). Changed files: web/app/teams/[team_id]/workflow/page.tsx, web/app/teams/[team_id]/workflow/WorkflowSettingsClient.tsx
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
