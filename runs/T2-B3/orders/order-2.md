# Work order 2 — small follow-up to order 1

Your order-1 change looks good. Two follow-ups:

## 1. Single source of truth for the access rule
`src/mem_mcp/teams/references.py` currently encodes the rule twice: as SQL in `caller_can_access_memory`
and as Python + SQL in `_caller_can_access_memory_row`. They can drift. Make the rule live in exactly one
place: implement `caller_can_access_memory` by fetching the memory's `tenant_id, team_id` (respecting
`include_deleted`; return False if no row) and delegating to `_caller_can_access_memory_row` (rename it to a
public `caller_can_access_memory_row` if you like, and update the unit tests accordingly — these are your own new
tests, so editing them is fine). Keep the module comments accurate. Behaviour must be unchanged; keep the opaque
`ReferenceTargetNotFoundError` contract in `resolve_reference_target`.

## 2. Full-suite comparison (your previous report was truncated before this)
- Run `pytest -q -p no:cacheprovider tests` on the current working tree and list every failing/erroring test id.
- Then `git stash -u`, run the same command on the baseline, list failures, then `git stash pop` (make sure the
  working tree is restored exactly — check `git status` afterwards shows the same 3 modified + 2 new files).
- Confirm the after-failures are a subset of the before-failures (excluding the repro test, which should now
  pass). If any new failure appears, fix it.
- Also re-run: the repro test, your two new test files, `ruff check src tests`, `mypy`.

## Report
Keep it concise: the change, the two failing-test lists (before/after), and the other command results.
