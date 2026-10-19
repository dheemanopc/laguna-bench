## Gate for wp0-t1-a1 (harness-run)
- ruff: FAIL
    tests/unit/test_migration_0048_workflow_schema.py:77:1: SyntaxError: Expected an indented block after `class` definition
       |
    75 | class TestNewTables:
    76 | # mem_app must hold exactly the privileges called out in wp0.md.
    77 | _MEM_APP_GRANTS_EXPECTED: dict[str, set[str]] = {
       | ^
    78 |     "team_workflows": {"SELECT", "INSERT", "UPDATE"},
    79 |     "workflow_stages": {"SELECT", "INSERT"},
       |
    
    Found 1 error.
- mypy (this task's files): clean
- tests: FAIL — 1 error in 0.16s
    ../../../wt/lead/.venv/lib/python3.12/site-packages/_pytest/assertion/rewrite.py:177: in exec_module
    ../../../wt/lead/.venv/lib/python3.12/site-packages/_pytest/assertion/rewrite.py:357: in _rewrite_test
    E   IndentationError: expected an indented block after class definition on line 75
    ERROR tests/unit/test_migration_0048_workflow_schema.py
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 323:+import asyncpg  # type: ignore[import-untyped]
RESULT: FAIL
