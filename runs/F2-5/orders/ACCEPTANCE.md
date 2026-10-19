# F2 Team workflows — Acceptance

## 1) Verdict: REJECT

6 of 28 tasks were done (WP0 + WP1). What shipped is migration 0048 and the domain modules under `src/mem_mcp/mindmap/` (`workflow_crud/moves/reads/errors.py` plus changes to `work_items.py`). There are no MCP tools (WP2), no service/web API, and no web board (the harness reports "web: no changes"). The WP1 milestone review came back REVISE with 5 correctness defects. Fix task WP1-R1 was created but never run. Gates are green only because nothing user-facing exists yet.

## 2) Requirements

| Req | Status | Evidence |
|---|---|---|
| R1 Team defines stages + moves | PARTLY | Tables in 0048, `workflow_crud.py` create/activate. Only callable from Python. |
| R2 Allowed moves | PARTLY | Domain checks `workflow_transitions` in `workflow_moves.py`. Not exposed. |
| R3 Reason / multi-person non-owner sign-off | PARTLY, defective | Sign-off flow exists. But when `signoff_roles` is empty, any tenant member can sign (workflow_moves.py:446). The request lookup is not filtered by team (:398, :586). |
| R4 Never stuck, history kept | PARTLY, defective | Remap, legacy materialisation and cancel exist. But committing a legacy item (`current_stage` NULL) updates 0 rows and still marks the request committed (:509/:542). |
| R5 Board in web app | NOT MET | No changes under `web/`. |
| R6 Move / blocked reason / waiting-on-me from board | NOT MET | Only domain reads exist (`compute_item_moves`, `list_pending_signoffs_for_user`). |
| R7 Agents via MCP tools | NOT MET | No new MCP tools. Existing work-item tools aren't extended. |

## 3) Defects that matter to users (most important first)

1. **No user-facing surface.** There's no board and no MCP tools, so neither people nor agents can use any of this.
2. **Sign-off can be bypassed.** Moves never write `work_items.workflow_id`, so the routing in `set_work_item_status`/`set_kind` (work_items.py:809) never fires. On top of that, `mark_work_item` (:628) doesn't route through `move_work_item`, and a gated `set_status` silently returns the unchanged item instead of raising `MoveBlockedError`. Gated moves can be skipped through the legacy entry points.
3. **Wrong people can sign off.** Non-team members can sign when no roles are configured, and requests can be signed or cancelled from another team's context.
4. **Lost commits on legacy items.** A request is marked committed while the item stays where it was, so the audit trail disagrees with the item's real state. That breaks "never lose history".
5. `tests/unit/mindmap/test_debug.py` is a leftover debug test that writes to the DB. Delete it.
6. The 18 failures and 16 errors in the suite are pre-existing ("NEW failures vs known red: 0").

To move toward acceptance: run WP1-R1, then WP2 (MCP), the service/API layer and the web board (WP3–WP5) as planned in `docs/feature/`.
