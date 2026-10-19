# F2 Team workflows — Acceptance

## 1) Verdict: ACCEPT WITH FIXES

The domain and the MCP layer are sound: migration 0048/0049, propose/sign/cancel, sign-off exclusion, the set_status gate, and lazy legacy materialisation all work. The final gate is red (1 new failure), and that failure is a real defect in the web settings flow. Three bounded fixes are required before shipping.

## 2) Requirements

| Req | Status | Evidence |
|---|---|---|
| R1 Team defines workflow | PARTLY | `workflow_crud.create_team_workflow/activate_workflow` + MCP tools work. The web flow is broken (defect 1). |
| R2 Allowed moves | MET | `workflow_moves._find_transition` (explicit from-stage beats "any entry"), `allowed_kinds`; `compute_item_moves` returns `no_transition`. |
| R3 Reason / multi-person sign-off, not owner | MET | `propose_move` (reason, pending request, `immediate_only` gate); `_is_eligible` excludes the owner and proposer and applies roles; `signoff_min`. |
| R4 Never stuck / history kept | PARTLY | The old workflow is retained, history is append-only, and MCP can cancel a proposal. However, remap can strand items and writes no history, and the web has no cancel (defects 2, 3). |
| R5 Board in web app | PARTLY | `web/app/mindmaps/[key]/board/*` has stage columns plus an "unmapped" column. No page links to the board or the settings page (defect 4). |
| R6 Move / why blocked / waiting on me | MET | `ItemDetail.tsx` (move dropdown, reason, blocked badge, history), `WaitingOnYou.tsx`, pending-signoffs endpoint. |
| R7 MCP parity | MET | 11 `mindmap_workflow_*`/`mindmap_work_*` tools. Web handlers call the same tools (`web/handlers/workflows.py`, `mindmaps.py`); e2e parity tests exist. |

## 3) Defects that matter to users (most important first)

1. **The settings page loads the wrong workflow for a draft, and a team's first workflow can't be activated in the web UI.** `GET /api/web/teams/{id}/workflow` ignores `?workflow_id=` (`web/handlers/workflows.py:63-70` always passes `workflow_id=None`).
   - If the team has no active workflow, the draft fetch fails and `canActivate` is never true.
   - If a workflow is already active, the "stages that will be removed" check compares against the active workflow's stages, so items are silently orphaned on activation.
   - This is the new gate failure (`test_get_workflow_by_id_returns_inactive_draft`).
2. **Remap can make items permanently stuck, and it loses history.** `remap_workflow_stages` changes `current_stage` but not `workflow_id`, and appends no `work_item_history` row.
   - Any item that has moved at least once is tied to the old workflow (set in `_commit_stage`). After a remap, its new stage name does not exist in that old workflow, so every move returns `TransitionNotFound`.
   - Remap should also re-point `workflow_id` to the active workflow and write a 'stage' history event.
   - Remap also ignores its `map_key` (it applies team-wide).
3. **The web app can't cancel a pending sign-off.** There is no cancel endpoint in `handlers/mindmaps.py` and no button in `ItemDetail`. A web-only team can only clear an unwanted proposal through MCP.
4. **The board and workflow settings pages can't be reached from anywhere in the UI**, because nothing links to `/mindmaps/[key]/board` or `/teams/[id]/workflow`.
5. Minor: `list_pending_signoffs_for_user` resolves the transition from the item's workflow rather than `r.workflow_id` (column added in 0049). It can show the wrong `signoff_min` or roles after a workflow change.
