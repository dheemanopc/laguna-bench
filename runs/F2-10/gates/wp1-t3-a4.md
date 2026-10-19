## Gate for wp1-t3-a4 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow_moves.py:11:5: F401 [*] `mem_mcp.mindmap.workflow_crud.WorkflowNotFoundError` imported but unused
       |
     9 | from mem_mcp.mindmap import work_items
    10 | from mem_mcp.mindmap.workflow_crud import (
    11 |     WorkflowNotFoundError,
       |     ^^^^^^^^^^^^^^^^^^^^^ F401
    12 |     activate_workflow,
    13 |     create_team_workflow,
       |
       = help: Remove unused import: `mem_mcp.mindmap.workflow_crud.WorkflowNotFoundError`
    
    tests/unit/mindmap/test_workflow_moves.py:16:5: F401 [*] `mem_mcp.mindmap.workflow_errors.MoveBlockedError` imported but unused
       |
    14 | )
    15 | from mem_mcp.mindmap.workflow_errors import (
    16 |     MoveBlockedError,
       |     ^^^^^^^^^^^^^^^^ F401
    17 |     ReasonRequiredError,
    18 |     SignoffNotAllowedError,
       |
- mypy (this task's files): clean
- tests: FAIL — 1 failed, 3 passed in 1.48s
                except SignoffRequiredError:
                assert rows
                raise WorkflowNotFoundError()
                raise SignoffCompleteError()
                    raise WorkflowError("request cancelled")
                raise SignoffCompleteError()
                raise SignoffNotAllowedError(signatory_tenant_id)
                raise SignoffNotAllowedError(signatory_tenant_id)
                raise SignoffNotAllowedError(signatory_tenant_id)
                raise SignoffAlreadySignedError() from exc
    E       TypeError: object function can't be used in 'await' expression
    src/mem_mcp/mindmap/workflow_moves.py:450: TypeError
    FAILED tests/unit/mindmap/test_workflow_moves.py::test_signoff_from_other - T...
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 665:+            return tid  # type: ignore[no-any-return]
    added: 676:+            return tid  # type: ignore[no-any-return]
    added: 704:+            return tid  # type: ignore[no-any-return]
RESULT: FAIL
