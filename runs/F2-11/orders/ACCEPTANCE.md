# F2 Team workflows: acceptance

## 1) Verdict: ACCEPT WITH FIXES

The schema, domain, MCP tools, web endpoints and board/settings UI are all in place, and the gates are green. However, the rules a team sets on moves can be bypassed or broken. Fixes 1–3 below must land before release.

## 2) Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Team defines its own stages and allowed moves | MET | `workflow_crud.create_team_workflow`/`activate_workflow`; `teams/[team_id]/workflow` editor |
| A move can require a reason | MET | `workflow_moves.propose_move` raises `ReasonRequiredError` |
| Sign-off from someone other than the owner, possibly several people | PARTLY | `sign_workflow_move` excludes the owner and proposer, enforces `signoff_min` and roles; but see defects 1–2 |
| Items never stuck when the workflow changes | PARTLY | Wildcard transitions, an "unmapped" board column and `remap_workflow_stages` exist. Items always follow the active workflow; remap only matches `current_stage = old` |
| History never lost | PARTLY | Stage moves and sign-offs append history; remap writes **no** history (`workflow_crud.py:587-622`) |
| Board in the web app with move and blocked reason | MET | `board/BoardView.tsx`, `ItemDetail.tsx`, `compute_item_moves.blocked_reason` |
| See what is waiting on me | PARTLY | `WaitingOnYou.tsx`; but see defect 4 |
| Agents can do the same through MCP | MET | 11 tools registered; e2e parity tests for the MCP and web paths |

## 3) Defects that matter to users (most important first)

1. **The workflow can be bypassed.** Nothing in production code ever sets `work_items.workflow_id`; the e2e tests set it with raw SQL. So the `set_status` workflow check at `work_items.py:631` never fires. Through the existing set_status tool, agents move items with the old built-in rules, with no sign-off or reason rules from the team's workflow. That also changes `status` while leaving `current_stage` stale, so the board and the status disagree.
2. **Stale sign-offs can teleport items.** Nothing stops a new move while a request is pending. When signed, the request commits `to_stage` without checking that the item is still at `from_stage`. Pending requests are also never cancelled on a move, an activation or a remap.
3. **Remap erases the audit trail.** It bulk-updates `current_stage`/`status` with no history row. Items with a NULL `current_stage` (every legacy item that has never moved) are never matched by a remap.
4. **"Waiting on me" is wrong in two ways:**
   - Scoping: the query runs in the caller's own tenant (`mindmap_workflow_pending_signoffs.py:41`), while signing looks up the item's tenant cross-tenant. A teammate in another tenant sees nothing to act on.
   - Wildcard moves: requests made through a wildcard (any-stage) transition are dropped (`workflow_reads.py:314`).
5. On the web, a sign-off that completes a move is recorded as channel `"mcp"`, and no map change event is recorded.
6. `blocked_reason="reason_required"` marks moves that are perfectly allowed as blocked.
7. A process breach: the existing `tests/unit/mindmap/test_workflow_errors.py` was cut from 287 to 74 lines. It loses the import-cycle and `ReasonRequiredError`-reuse checks. Restore it.
8. No design doc or ADR was updated under `docs/`.
