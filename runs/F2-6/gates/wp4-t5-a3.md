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
