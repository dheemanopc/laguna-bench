# F2 Team workflows: Shadow acceptance

## 1) Verdict: REJECT

Only the backend and MCP half exists, and it regressed existing behaviour. The harness gates are red: 18 new test failures, 28 mypy errors and 10 ruff findings. The web board, the blocked-reason display and the waiting view are missing. The last architect review (`review-wp2-1.md`) said REVISE, and none of its points were fixed.

## 2) Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Team defines its own stages and allowed moves | PARTLY | `mindmap/workflows.py`, `mindmap_workflow_get/update`. `test_workflow_edit_refuses_orphan_statuses` fails. |
| A move can require a reason | PARTLY | The logic exists. `test_work_item_blocked_without_reason_rejected`, `test_work_item_cancelled_without_reason_rejected` and `test_work_item_reason_blank_rejected` were green before and are now red. |
| Sign-off from someone other than the owner, possibly several people | PARTLY | Approve, reject and list tools exist. `test_signoff_reject_does_not_move` fails. `set_status` reports success when it only requested sign-off. |
| Items never stuck; history kept when the workflow changes | PARTLY | Frozen `workflow_id`, a rebase tool and `workflow_changed` history exist. The orphan-guard test is red. There is no web rebase. |
| Board in the web app | NOT MET | The gate says "web: no changes". There are no board endpoints and no pages. |
| See why a move is blocked | NOT MET | `blocked` is set to `status == "blocked"` (`_work_item_common.py:178`). It is not the guard or sign-off reason. There is no UI. |
| See what is waiting on me | PARTLY | Only the MCP `mindmap_work_list(waiting_on_me)` exists. There is no web view. |
| Agents can do the same through MCP | PARTLY | Nine tools are registered, but every error path crashes (defect 1). |
| No regressions; static gates green | NOT MET | 18 new failures, mypy 28 errors, ruff 10 findings. |

## 3) Defects that matter to users

1. **Every work-item error response crashes.** `map_work_item_error` uses `JsonRpcError` but never imports it (`_work_item_common.py:182` onward). Bad transitions, missing reasons, duplicate marks and wrong kinds return an internal error instead of the old messages. This broke about 12 previously passing tests.
2. **No web UI.** The board, the blocked reason and the waiting-on-me list can only be reached through agents. Moving work in the web app, a core part of the ask, is impossible.
3. **A sign-off request looks like a completed move.** `set_status` returns a normal success payload and audits `change:"status"` although the item did not move (`mindmap_work_set_status.py:63-80`). The approver list is always `[]`, so nobody can tell who must sign.
4. **Workflow errors are not mapped.** The tools catch only `WorkItemError`. `SignoffAlreadyPending` and `WorkflowNotFound` surface as internal errors.
5. **New teams are not seeded with a default workflow.** `ensure_default_workflow` is called only from `workflows.py` itself, not from team creation (personal team, web `create_team`, MCP `create_team`). Behaviour for teams created after the migration depends on lazy creation.
