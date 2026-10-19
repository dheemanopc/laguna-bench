## Gate for wp5-t2b-a1 (harness-run)
- ruff: FAIL
    tests/integration/test_mindmap_workflow_web_e2e.py:17:8: F401 [*] `asyncpg` imported but unused
       |
    15 | from uuid import UUID, uuid4
    16 | 
    17 | import asyncpg  # type: ignore[import-untyped]
       |        ^^^^^^^ F401
    18 | import pytest
    19 | from fastapi.testclient import TestClient
       |
       = help: Remove unused import: `asyncpg`
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: FAIL — 3 failed, 2 passed, 6 warnings in 4.26s
                assert resp.status_code == 200
    >           assert data["status"] == "awaiting_signoff"
    E           KeyError: 'status'
    tests/integration/test_mindmap_workflow_web_e2e.py:333: KeyError
                assert resp.status_code == 200
    >           assert resp.status_code == 200
    E           assert 404 == 200
    tests/integration/test_mindmap_workflow_web_e2e.py:359: AssertionError
                assert resp.status_code == 200
                assert resp.status_code == 200
    >           assert len(requests) >= 1
    E           assert 0 >= 1
    tests/integration/test_mindmap_workflow_web_e2e.py:396: AssertionError
    FAILED tests/integration/test_mindmap_workflow_web_e2e.py::TestWorkflowWebE2E::test_propose_move_awaiting_signoff
    FAILED tests/integration/test_mindmap_workflow_web_e2e.py::TestWorkflowWebE2E::test_sign_workflow_move
    FAILED tests/integration/test_mindmap_workflow_web_e2e.py::TestWorkflowWebE2E::test_pending_signoffs_read
    (some tests skipped — check they are not skipped on purpose)
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 17:+import asyncpg  # type: ignore[import-untyped]
    added: 22:+pytestmark = pytest.mark.skipif(
RESULT: FAIL
