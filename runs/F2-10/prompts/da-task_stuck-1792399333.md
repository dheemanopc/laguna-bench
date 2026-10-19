EVENT task_stuck. Task WP1-T4 (workflow_reads.py: compute_item_moves + list_pending_signoffs_for_user) is still failing after 3 attempts.
Last gate output:
## Gate for wp1-t4-a3 (harness-run)
- note: planned files not present: tests/unit/mindmap/test_workflow_reads.py
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — none of the planned test files exist (tests/unit/mindmap/test_workflow_reads.py)
RESULT: FAIL

Engineer's last response:
API Error: 402 This request would exceed your available credits given your current in-flight requests. Retry after in-flight requests settle, or add credits.
Decide. Options: "retry" with precise guidance (what is wrong and how to fix it), "split" into smaller tasks (give them
in the same shape as the plan JSON), "accept" (the failure is not caused by this task; say why), or "escalate" to the
architect (only for a design contradiction you cannot resolve).
Reply json: {"action":"retry|split|accept|escalate","guidance":"<=6 lines","new_tasks":[]}