EVENT task_stuck. Task WP5-T2a (Integration e2e (MCP path) — define→propose(sign-off)→sign→commit, no-signoff commit, set_status gate, sign-off exclusion + role restriction, remap/unmapped, blocked reasons, codes — tests/integration/test_mindmap_workflows_e2e.py) is still failing after 3 attempts.
Last gate output:
## Gate for wp5-t2a-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 6 passed in 3.10s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 59:+pytestmark = pytest.mark.skipif(
RESULT: FAIL

Engineer's last response:
.16s; ruff check tests/integration/test_mindmap_workflows_e2e.py -> All checks passed!
CHECKLIST:
#1 FIXED module-level `pytestmark = skipif(not os.getenv("MEM_MCP_TEST_DSN"))` plus `import os`, copied from test_mindmap_work_items_e2e.py.
#2 FIXED in test_blocked_reasons_and_error_codes, a member makes its own item and is then demoted to viewer. The blocked reason is read from `mindmap_work_list` `allowed_moves` (`role_restricted`). `propose_move` is asserted to raise `data.code == "role_restricted"`.
#3 NOT FIXED nothing in `src/mem_mcp/mindmap` raises `SignoffRequiredError`, so no tool path can produce `signoff_required` end to end. I kept the mapping test and wrote the gap into its docstring.
#4 FIXED test_remap_and_unmapped_items now has a third item left out of the mapping. After the remap it keeps `current_stage` (DB value still None, the board shows `in_progress`) and its moves are all `no_transition`. The two mapped items move to `backlog`.
#5 FIXED the no-transition case now asserts `data.code == "transition_not_found"` exactly.
NOTES:
- The first run failed with `relation "workflow_signoffs" does not exist`; running `alembic upgrade head` fixed it. That is an environment step, not a code change.
- `mindmap_work_list` only returns the caller's own items, so the viewer check uses a separate item and map created by the viewer before demotion.
- An item that predates the workflow has a NULL `current_stage` in the DB; the board shows its legacy status in `current_stage`.
Decide. Options: "retry" with precise guidance (what is wrong and how to fix it), "split" into smaller tasks (give them
in the same shape as the plan JSON), "accept" (the failure is not caused by this task; say why), or "escalate" to the
architect (only for a design contradiction you cannot resolve).
Reply json: {"action":"retry|split|accept|escalate","guidance":"<=6 lines","new_tasks":[]}