# Work order 2 — verify order 1, plus two small fixes

Good work on order 1; the design is right. Nothing has been run yet, so verification is the priority.
Bash should now be usable. If it is still denied, say so in the first line of your report and stop.

## Fixes
1. `src/mem_mcp/mcp/tools/mindmap_resolve.py`: validate the map and node before the resolver access
   check, so that an unknown map, an archived map, a non-member node, the root or an already-settled node
   gets its own error even when `resolved_by_memory_id` is also given (a stray resolver id must never hide
   a "wrong map" error). Suggested flow:
   (a) a read `tenant_tx`: team → map → live → member → not root → open (the existing errors);
   (b) if a resolver is given: self-check, then the `system_tx` `resolve_reference_target` check;
   (c) a write `tenant_tx`: re-check map live, then `settle_member` (conditional UPDATE →
       `NodeNotOpenError` → `node_not_open`), `insert_reference`, `log_event`, all in that one tx.
   In (c), re-fetch the member to get `team_id`, or carry it over from (a). Add a test: resolve on a node
   of another map AND with a valid resolver → -32602 with path `node_id`, nothing changed.
2. `service.MapNodeNotFoundError` is unused. Remove it or use it. Don't leave dead code.

## Verify (exact commands, report the results)
1. `alembic upgrade head`, then `alembic downgrade -1 && alembic upgrade head`.
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py`. Everything must pass. Fix the code (or your
   new tests, if a test itself is wrong) until it does.
3. `pytest -q -p no:cacheprovider tests/unit tests/integration`, then the full `pytest -q -p no:cacheprovider`.
   For every failure, decide whether it is pre-existing: check it against `git stash -u` → run that
   test → `git stash pop` (the DB being at 0044 doesn't affect the old code), or reason from the error
   if it's obviously a known fixture collision. List the failures and say which are new. There must be
   no new failures, including registry/tool-count/description-completeness tests and
   `tests/unit/test_lint_tenant_scope.py`.
4. `ruff check src tests`, `ruff format --check` on the files you touched (format them if needed),
   and `mypy` (project config). No new errors in touched files.

Report: changes made, and each command with its exact pass/fail counts.
