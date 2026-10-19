# Work order 6 — verification only (no code changes)

Do not edit any file. Run these commands and paste their **literal output** (the last lines are enough where noted).
I need the raw text, not a summary.

```
cd <repo root>
alembic downgrade -1 && alembic upgrade head && alembic current
pytest -q -p no:cacheprovider tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py 2>&1 | tail -3
pytest -q -p no:cacheprovider -rfE > /tmp/after_full.txt 2>&1; tail -1 /tmp/after_full.txt
grep -E '^(FAILED|ERROR) ' /tmp/after_full.txt | sed 's/ - .*//' | sort -u > /tmp/after.txt
git stash -u
pytest -q -p no:cacheprovider -rfE > /tmp/before_full.txt 2>&1; tail -1 /tmp/before_full.txt
grep -E '^(FAILED|ERROR) ' /tmp/before_full.txt | sed 's/ - .*//' | sort -u > /tmp/before.txt
git stash pop && git status --short
wc -l /tmp/before.txt /tmp/after.txt
echo "--- new failures (must be empty):"; comm -13 /tmp/before.txt /tmp/after.txt
echo "--- fixed vs baseline:"; comm -23 /tmp/before.txt /tmp/after.txt
ruff check src tests | tail -3
ruff format --check src/mem_mcp/mindmap/service.py src/mem_mcp/mcp/tools/mindmap_get.py src/mem_mcp/mcp/tools/mindmap_resolve.py alembic/versions/0044_2026_10_15_mindmap_branch_status.py tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py
mypy 2>&1 | tail -3
```

If `comm -13` is non-empty, investigate each new failure and report whether it is caused by our change (flakiness
from the shared DB counts as "investigate": rerun that test alone on both trees and report). Do not fix anything
in this order — just report.
