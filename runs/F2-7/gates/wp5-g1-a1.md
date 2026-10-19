## Gate for wp5-g1-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: FAIL — 1 failed, 38 passed, 6 warnings in 7.79s
        | asyncpg.exceptions.UndefinedTableError: relation "mindmap_graph" does not exist
    asyncpg.exceptions.UndefinedTableError: relation "mindmap_graph" does not exist
                assert resp.status_code == 200
    E   asyncpg.exceptions.UndefinedTableError: relation "mindmap_graph" does not exist
    asyncpg/protocol/protocol.pyx:165: UndefinedTableError
    FAILED tests/integration/test_mindmap_workflow_web_e2e.py::TestWorkflowWebE2E::test_sign_workflow_move
    (some tests skipped — check they are not skipped on purpose)
RESULT: FAIL
