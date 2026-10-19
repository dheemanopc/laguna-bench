## Harness gate results (run by the harness, not by the engineer)
- ruff: [*] 10 fixable with the `--fix` option (2 hidden fixes can be enabled with the `--unsafe-fixes` option).
- mypy: Found 28 errors in 4 files (checked 193 source files)
- alembic heads: 1
- tests added/changed: 2 files
- full suite:  36 failed, 1421 passed, 31 skipped, 94 warnings, 16 errors in 18.68s
- NEW failures vs known red: 18
    tests/integration/test_mindmap_workflows_e2e.py::test_mark_work_item_stamps_live_workflow_and_validates_entry
    tests/integration/test_mindmap_workflows_e2e.py::test_signoff_reject_does_not_move
    tests/integration/test_mindmap_workflows_e2e.py::test_workflow_edit_refuses_orphan_statuses
    tests/integration/test_mindmap_work_items_e2e.py::test_get_and_history_tools_enriched
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_archived_map_mark_rejected_status_change_works
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_blocked_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_cancelled_without_reason_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_disallowed_transition_error
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_expected_status_mismatch
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_kind_change
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_bad_kind_error
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_duplicate_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_node_from_another_map
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_mark_root_node_rejected
    tests/integration/test_mindmap_work_items_e2e.py::test_work_item_reason_blank_rejected
- web: no changes

## Change summary vs baseline (read-only)
 src/mem_mcp/mcp/tools/mindmap_work_history.py      |   95 ++
 src/mem_mcp/mcp/tools/mindmap_work_list.py         |  100 ++
 src/mem_mcp/mcp/tools/mindmap_work_mark.py         |   18 +-
 src/mem_mcp/mcp/tools/mindmap_work_set_kind.py     |   16 +-
 src/mem_mcp/mcp/tools/mindmap_work_set_status.py   |   16 +-
 .../mcp/tools/mindmap_work_signoff_approve.py      |   68 ++
 src/mem_mcp/mcp/tools/mindmap_work_signoff_list.py |   63 ++
 .../mcp/tools/mindmap_work_signoff_reject.py       |   70 ++
 src/mem_mcp/mcp/tools/mindmap_workflow_get.py      |   76 ++
 src/mem_mcp/mcp/tools/mindmap_workflow_rebase.py   |   85 ++
 src/mem_mcp/mcp/tools/mindmap_workflow_update.py   |   80 ++
 src/mem_mcp/mindmap/work_items.py                  |  349 ++++--
 src/mem_mcp/mindmap/workflows.py                   | 1162 ++++++++++++++++++++
 tests/integration/test_mindmap_work_items_e2e.py   |  112 +-
 tests/integration/test_mindmap_workflows_e2e.py    |  607 ++++++++++
 .../test_mindmap_workflows_migration.py            |  627 +++++++++++
 tests/security/test_workflow_visibility.py         |  163 +++
 tests/unit/test_workflows_service.py               |  847 ++++++++++++++
 tools/lint_tenant_scope.py                         |    4 +
 30 files changed, 6959 insertions(+), 183 deletions(-)
