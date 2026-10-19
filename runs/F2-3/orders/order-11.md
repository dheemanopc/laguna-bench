The architect reviewed your wp0 and asked for revisions:

VERDICT: REVISE

1. 56 NEW failures (gate lines 7-22, all of `test_mindmap_work_items_e2e.py`): `work_items.workflow_id SET NOT NULL` (0048:289) lands before anything stamps it. `mark_work_item` doesn't write the column yet (WP1), and teams created after the migration get no pointer (hooks are WP3). This breaks the plan's promise that WP0 "ships idempotently alone" (plan:103). Fix: leave the column nullable until WP1 stamps it, or add a DB default/trigger that resolves the team's live version and seeds a missing pointer. The existing e2e suite must be green again.
2. None of the planned WP0 tests exist. `tests/integration/test_mindmap_workflows_migration.py` (plan:115-150) is missing all 7 tests: seed, back-fill, CHECK dropped, change_type relaxed, INSERT-only under RLS, cross-tenant A/B/C read/move/history, sign-off isolation. The only test added is `tests/security/test_workflow_visibility.py`, which belongs to WP3 and doesn't cover the RLS regression the plan centres on (the B-moves-A's-item case).
3. `downgrade()` fails as written: it drops `team_workflow_versions` (0048:463) while the `work_items.workflow_id` FK still references it. The column is only dropped later (0048:473). Drop the column first.
4. `work_items.workflow_id ... ON DELETE SET NULL` (0048:220) contradicts `NOT NULL` (0048:289). Use RESTRICT to match the other version FKs (0048:103, 198).
5. Nothing makes `team_workflow_versions` actually frozen. RLS has no UPDATE policy, but `mem_app` has no DELETE/UPDATE grant either, so it's fine for now. The plan's "cannot UPDATE" test (plan:131-134) is what proves this, and it's still unwritten (see 2).

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

Fix these in the code and tests for WP0, re-run the tests. When done, end your turn with a 3-line summary of what you changed.
