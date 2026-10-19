# F2 Team Workflows — Acceptance

## 1. Verdict: **REJECT**

## 2. Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Team defines its own stages | PARTLY | `teams/workflows.py:199` stores them, but `work_items.status` CHECK still allows only the 5 built-in values (`0046…:49`), and 0048 doesn't drop it. Any custom status fails on insert or update. |
| Team defines allowed moves | MET (logic only) | `check_transition` `work_items.py:255`, `_team_pipeline` `:456` |
| Move requires a reason | MET (logic only) | `reason_required` per edge, `work_items.py:273` |
| Sign-off from someone other than the owner, possibly several people | NOT MET | No approval model in schema, service or tools. Design doc doesn't mention it. |
| Items never get stuck when the workflow changes | NOT MET | `set_workflow` doesn't check existing item statuses. If an item's status isn't in the new workflow, it has no outgoing edge and can't move (`work_items.py:653,669`). |
| History survives a workflow change | PARTLY | Item history table is untouched. Workflow changes aren't versioned: wipe+reinsert at `workflows.py:257`, hard delete at `:300`. |
| Web board: view and move items | NOT MET | No changes under `web/`. The web handlers in design doc §Web handlers don't exist. |
| See why a move is blocked | NOT MET | No API that lists allowed or blocked moves. Agents only learn the reason by attempting a move and getting the error. |
| See what is waiting on me | NOT MET | Nothing built |
| Agents via MCP | PARTLY | `memsys_workflow_set/get/delete` are registered (`main.py:532-534`). There's no approval tool and no "what's waiting on me" query. |
| Tests | NOT MET | No test files were added (`delivered.stat`) |
| Design doc | PARTLY | It exists, but it narrows the scope without saying so and describes web handlers that weren't built |

## 3. Design soundness
- Overriding the pipeline per team with a fallback to the built-in one is a sound approach. It's undermined by the leftover status CHECK constraint.
- A normalised transitions table plus DB triggers and admin-only RLS is reasonable layering.
- With no workflow versioning and no status-mapping step, the "never stuck / keep history" requirement can't be met.
- The ask was turned into a reason-only status pipeline. Approvals, which were the core of the request, were dropped without any question being raised.
- `get_workflow` contains a dead "coerce" branch (`workflows.py:174-175`).

## 4. Defects
1. Custom statuses can't be used. Inserts and updates violate `work_items_status_check`, so the feature is inert in practice.
2. Changing the workflow strands items whose status was removed. There's no migration or mapping path.
3. `delete_workflow` calls `result.rowcount` on asyncpg's status string (`workflows.py:301`). That raises AttributeError, so `memsys_workflow_delete` always fails.
4. No sign-off or approvals (single or multiple approvers), no board, no blocked-move explanation and no "waiting on me". About half the request wasn't built.
5. No tests at all. Nothing exercised the defects above.
