## Harness gate results (run by the harness, not by the engineer)
- ruff: All checks passed!
- mypy: Success: no issues found in 183 source files
- alembic heads: 1
- tests added/changed: 1 files
- full suite:  74 failed, 1344 passed, 31 skipped, 94 warnings, 16 errors in 18.64s
- NEW failures vs known red: 56
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_archived_map_mark_rejected_status_change_works
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_assign_reassign_unassign
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_blocked_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_branch_status_unchanged
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_cancelled_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_disallowed_transition_error
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_expected_status_mismatch
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_get_for_plain_node_unchanged
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_history_one_row_per_success
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_kind_change
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_duplicate_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_happy_path_story
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_milestone_kind
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_with_assignee
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_reason_blank_rejected
- web: no changes

## Change summary vs baseline (read-only)
 alembic/versions/0048_2026_10_16_team_workflows.py | 531 +++++++++++++++++++
 docs/feature/01-analysis.md                        | 577 ++++++++++++++++++++
 docs/feature/02-design.md                          | 578 +++++++++++++++++++++
 docs/feature/03-plan.md                            | 423 +++++++++++++++
 tests/security/test_workflow_visibility.py         | 163 ++++++
 5 files changed, 2272 insertions(+)
