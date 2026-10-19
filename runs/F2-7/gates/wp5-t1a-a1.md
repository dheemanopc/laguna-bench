## Gate for wp5-t1a-a1 (harness-run)
- ruff: FAIL
    tests/unit/mindmap/test_workflow.py:10:1: UP035 [*] Import from `collections.abc` instead: `AsyncGenerator`
       |
     9 | import os
    10 | from typing import AsyncGenerator, cast
       | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ UP035
    11 | from uuid import UUID, uuid4
       |
       = help: Import from `collections.abc`
    
    Found 1 error.
    [*] 1 fixable with the `--fix` option.
- mypy (this task's files): clean
- tests: 17 passed in 2.27s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 34:+    pytest.mark.skipif(
RESULT: FAIL
