# F2 Team workflows — Acceptance

## 1) Verdict: REJECT

The gates are green (0 new failures, tsc/build OK), but the core user journey doesn't work. No product code path ever sets `work_items.workflow_id`. `grep "SET workflow_id"` in `src/` returns nothing. `move_work_item` resolves a workflow and then throws the result away (`work_items.py` `_resolve_workflow` call). After that, `propose_move` raises `MoveBlockedError("item has no workflow assigned")` for every NULL-workflow item (`workflow_moves.py:88-91`). The tests hide this: they assign the workflow with raw SQL (`test_mindmap_workflows_e2e.py:293` says "WP1 should do this automatically on mark").

## 2) Requirements

| Req | Status | Evidence |
|---|---|---|
| R1 define workflow | MET | `workflow_crud.py` create/activate/get; `mindmap_workflow_create/activate` tools; settings page `web/app/teams/[team_id]/workflow/` |
| R2 allowed moves | PARTLY | Transitions are stored and checked. `propose_move` ignores "from any" (NULL `from_stage`) transitions and `allowed_kinds` (`workflow_moves.py:109-112`) |
| R3 reason / multi-person sign-off | PARTLY | Reason, `signoff_min`, roles and the owner/proposer exclusion are coded. Requests are scoped to the proposer's `tenant_id`, and no test has a second tenant sign through the tool |
| R4 no stuck items / history kept | NOT MET | Items can't join a workflow, so legacy items can't be moved. Remap (`workflow_crud.py:433`) rewrites `current_stage` for every team item matching the name: it doesn't filter by workflow and writes no history row |
| R5 board in web app | PARTLY | Board, `ItemDetail` and `WaitingOnYou` exist. Moves fail as in §1 |
| R6 move / blocked reason / waiting-on-you | PARTLY | Endpoints and UI exist; the move action is broken by §1 |
| R7 MCP parity | PARTLY | 11 tools registered and web delegates to them, so both paths share the same defects |

## 3) Defects that matter to users (most important first)

1. **Items can never enter a workflow** (§1). Creating an item, activating a workflow or calling `move_work_item` never sets `workflow_id`, so every board move fails with "item has no workflow assigned".
2. **Cross-person sign-off probably fails.** `sign_workflow_move` and the signoff tool look up the request with `tenant_id = signatory`, and RLS is per tenant. A teammate in another tenant likely gets "request not found". The e2e tests never exercise this.
3. **Remap is unsafe.** It changes stages across all of the team's items with no `workflow_id` filter and writes no history. It also never moves items onto the new workflow, which is exactly the "change workflow" case R4 is about.
4. **Stale commits.** Committing a sign-off doesn't re-check that the item is still in `from_stage`. Several pending proposals per item are allowed, so an approval can overwrite a newer stage.
5. **Wrong history channel.** The sign-off commit and `signoff_approved` history are hardcoded to `channel="mcp"` and actor "model", even for web users. Cancellations write no `work_item_history` row.
6. **Rules not enforced.** "From any stage" transitions and `allowed_kinds` are ignored.
7. **Thin WP5 e2e coverage.** `test_mindmap_workflows_e2e.py` has only 2 tests, versus the scenario list the work order specified (propose→sign→commit, remap, role restriction).
