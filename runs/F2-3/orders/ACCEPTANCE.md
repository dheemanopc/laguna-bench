# F2 Team workflows: Acceptance

## 1) Verdict: **REJECT**

Only WP0–WP2 of the six-package plan (`docs/feature/03-plan.md`) were attempted. The last architect review (`review-wp2-1.md`) is **REVISE** and was never addressed. In the final gates there is **no web change**, **18 new test failures** (12 of them previously-green work-item tests), **28 mypy errors** and **ruff dirty**. WP3 (web API), WP4 (board UI) and WP5 (verification) were not done.

## 2) Requirements

| Requirement (backlog) | Status | Evidence |
|---|---|---|
| Team defines its own stages and allowed moves | PARTLY | `workflows.py`, migrations 0048/0049, `mindmap_workflow_update`. Its e2e test fails (`test_workflow_edit_refuses_orphan_statuses`). |
| Move needs a reason | PARTLY | Logic exists. `test_work_item_blocked/cancelled_without_reason_rejected` are now red. |
| Sign-off from a non-owner, possibly several people | PARTLY | Domain quorum code and approve/reject tools exist. `set_status` returns *success* and audits `change:"status"` when nothing moved (`mindmap_work_set_status.py:63-80`). `approvers` is always `[]`. `test_signoff_reject_does_not_move` fails. |
| Items never stuck; history kept on workflow change | PARTLY | Frozen `workflow_id`, rebase tool, `workflow_changed` history. No web rebase. The orphan guard test is red. |
| Board in the web app | NOT MET | Gate: "web: no changes". No board endpoints in `web/handlers/mindmaps.py`. |
| See why a move is blocked | NOT MET | `blocked` = `status=="blocked"` (`_work_item_common.py:178`), not the guard. There is no UI. |
| See what is waiting on me | PARTLY | Only the MCP `mindmap_work_list(waiting_on_me)`. No web page. |
| Agents can do the same via MCP | PARTLY | 9 new tools are registered, but every error path crashes (see defect 1). |
| No regressions; gates green | NOT MET | 18 new failures; mypy 28 errors; ruff 10 issues. |

## 3) Defects that matter to users

1. **All work-item error responses crash.** `map_work_item_error` uses `JsonRpcError` but never imports it (`_work_item_common.py:182`). Any invalid move, missing reason or duplicate mark returns an internal error instead of a useful message. This breaks behaviour that worked before the change.
2. **No web board, waiting view or blocked-reason display.** Half of the user-facing request is missing. People can't use this feature without an agent.
3. **Sign-off moves are reported as successful.** A move that only *requested* sign-off returns a normal success payload and an audit record saying the status changed. Users and agents will think the item moved. The approver list is always empty.
4. **Workflow errors aren't mapped.** Tools catch only `WorkItemError`. `SignoffAlreadyPending` and `WorkflowNotFound` surface as internal errors.
5. **Teams created through the MCP tool or the web are not seeded with a workflow** (`ensure_default_workflow` is never called from the team-creation code). A workflow is only created lazily on first use, so the planned seeding tests and the INSERT policy under RLS are never exercised.
