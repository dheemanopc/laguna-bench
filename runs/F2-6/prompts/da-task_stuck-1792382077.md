EVENT task_stuck. Task WP4-T5 (Shape-contract test (WP3 only): assert board-list/workflow/pending-signoffs response shapes the UI reads) is still failing after 3 attempts.
Last gate output:
## Gate for wp4-t5-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — 3 failed, 3 passed, 6 warnings in 2.70s
    >       assert body["team_id"] == str(env.team)
    E       KeyError: 'team_id'
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:246: KeyError
            assert body["workflow_id"] == str(env.workflow_id)
            assert body["is_active"] is True
            assert isinstance(body["name"], str)
            assert isinstance(body["version"], int)
            assert [s["name"] for s in stages] == _STAGES
            assert [s["ordinal"] for s in stages] == sorted(s["ordinal"] for s in stages)
                assert {"stage_id", "name", "ordinal", "is_initial", "is_terminal"} <= set(s)
            assert len(transitions) == 2
    >           assert {"from_stage", "to_stage", "requires_reason", "requires_signoff", "signoff_min",
    E           AssertionError: assert {'allowed_kin...f_roles', ...} <= {'allowed_kin...f_roles', ...}
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:311: AssertionError
            assert len(rows) == 1
    >           assert key in row, f"pending-signoffs row missing {key}"
    E           AssertionError: pending-signoffs row missing node_id
    E           assert 'node_id' in {'from_stage': 'review', 'memory_id': 'f04b215e-1c78-4500-9122-32882124ac38', 'proposer_tenant_id': '5ee226a5-2e1f-4a73-825a-232966c89f5d', 'reason': 'ship it', ...}
    tests/integration/test_mindmap_workflow_web_ui_shapes.py:326: AssertionError
    FAILED tests/integration/test_mindmap_workflow_web_ui_shapes.py::test_board_list_item_shape
RESULT: FAIL

Engineer's last response:
s[]` (`KeyError: 'team_id'`). The UI in `page.tsx` and `BoardView.tsx` reads both. The fix belongs in the WP3 list tool and `WorkListOutput`.
#2 NOT FIXED: workflow transitions carry `from_stage_id` and `to_stage_id` (UUIDs, from `WorkflowTransitionOutput` in `_work_item_common.py`). `docs/feature/wp4.md` specifies `from_stage` and `to_stage` as stage names.
#3 NOT FIXED: `PendingSignoffOutput` has `memory_id` and no `node_id`. `WaitingOnYou.tsx` joins rows to board items by `row.node_id`, and `wp4.md` says the rows carry `node_id`.
NOTES:
- These are real mismatches between the WP3 backend and the WP4 contract, not test bugs. Fixing them means editing shared WP3 files (`_work_item_common.py`, the list, workflow and pending-signoffs tools, `workflow_reads.py`) that other engineers are changing. I left the test and those files untouched.
- Earlier this run, the `team_workflows` table was missing from the test database. `alembic upgrade head` fixed that, so it is an environment issue.
- The WP3 owner needs to add four things:
  - top-level `team_id` on `WorkListOutput`
  - `transitions[]` on the board list
  - `from_stage` and `to_stage` names on workflow transitions
  - `node_id` on `PendingSignoffOutput`, which is probably `memory_id` renamed or added as an alias
- Alternatively, change the contract in `wp4.md` to match the current shapes.
- Pending-signoffs responses are wrapped as `{"requests": [...]}`. `WaitingOnYou.tsx` already reads `data.requests`, and the test matches.
Decide. Options: "retry" with precise guidance (what is wrong and how to fix it), "split" into smaller tasks (give them
in the same shape as the plan JSON), "accept" (the failure is not caused by this task; say why), or "escalate" to the
architect (only for a design contradiction you cannot resolve).
Reply json: {"action":"retry|split|accept|escalate","guidance":"<=6 lines","new_tasks":[]}