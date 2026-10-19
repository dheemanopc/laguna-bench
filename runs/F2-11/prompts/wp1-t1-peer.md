You are reviewing a teammate's finished task. Do NOT edit any file. Task WP1-T1: Shared workflow exception hierarchy in workflow_errors.py
Acceptance: workflow_errors.py defines WorkflowError(Exception) base + MoveBlockedError/ReasonRequiredError-reuse/SignoffRequiredError/SignoffCompleteError and the CRUD/signoff exceptions with their documented attrs; ReasonRequiredError is reused from mindmap.work_items (same class object) so legacy + workflow paths share one reason gate; DB-free pytest passes; importing workflow_errors has no runtime deps on work_items/workflow_* modules (no import cycle); lint_tenant_scope / ruff / mypy clean on the new module
Package plan: `docs/feature/wp1.md` (DESIGN section). Changed files: src/mem_mcp/mindmap/workflow_errors.py, tests/unit/mindmap/test_workflow_errors.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
