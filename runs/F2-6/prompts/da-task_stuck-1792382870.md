EVENT task_stuck. Task WP5-T1a (Domain lifecycle unit tests (create/activate/get/legacy-materialise/remap + workflow-change preservation) — tests/unit/mindmap/test_workflow.py) is still failing after 3 attempts.
Last gate output:
## Gate for wp5-t1a-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 17 passed in 5.71s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 46:+pytestmark = pytest.mark.skipif(
RESULT: FAIL

Engineer's last response:
s == "todo"` and that this stage is in the legacy workflow. New `test_resolve_workflow_null_id_uses_active_when_team_has_one` covers an active workflow with an item whose `workflow_id` is NULL.
#2 FIXED `test_activating_new_workflow_keeps_item_workflow_stage_and_history` now moves the item with the real `move_work_item` before activating a new workflow. It then asserts that the history row has `stage_before="backlog"` and `workflow_id=old`, and that the item keeps its old `workflow_id` and `current_stage`.
#3 FIXED Items are now built through `MindmapOpenTool`, `MindmapWriteNodeTool`, `mark_work_item` and `move_work_item`, using the `_build_deps` pattern (`NoopAuditLogger`, stub embed, `NoopQuotas`). The `env` fixture also seeds `tenant_identities` and an `oauth_clients` row, and its cleanup now covers them.
#4 FIXED The remap test now has three mapping pairs and mixes legacy items (NULL `workflow_id`) with an item owned by the new workflow. It asserts the owned item's `workflow_id` is unchanged. New tests cover a target stage outside the active workflow (`StageNotFoundError`), no active workflow (`WorkflowError`), and an unmapped item keeping its stage.
NOTES:
- `alembic upgrade head` was needed first because `team_workflows` didn't exist in the test DB. It ran without error.
- A `move_work_item` to "in_progress" on a legacy item relies on the legacy workflow's transitions. The test passed.
- The `ruff` check ran on the test file only. I did not run `mypy` or the full suite.
Decide. Options: "retry" with precise guidance (what is wrong and how to fix it), "split" into smaller tasks (give them
in the same shape as the plan JSON), "accept" (the failure is not caused by this task; say why), or "escalate" to the
architect (only for a design contradiction you cannot resolve).
Reply json: {"action":"retry|split|accept|escalate","guidance":"<=6 lines","new_tasks":[]}