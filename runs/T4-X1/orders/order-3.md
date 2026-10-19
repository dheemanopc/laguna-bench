# Work order 3 — evidence of no regressions + tiny cleanups

Code looks good now. Two small things, then proof.

1. `src/mem_mcp/mindmap/service.py`: the `cast(UUID | None, await conn.fetchval(...))` wrapping in `resolve_map_root`
   and `find_live_map_seeded_from` — check `git stash`-free: run `mypy` with those two functions restored to their
   original form (`return await conn.fetchval(...)`). If mypy is clean with the original form, restore the original
   (no diff in those functions). Only keep a cast if mypy fails without it, and then format it per `ruff format`.
2. Run `ruff format --check` on the files you created/changed (only if the repo's other files pass it — check one,
   e.g. `ruff format --check src/mem_mcp/mcp/tools/mindmap_link.py`); if the repo uses ruff format, format your files.
   Do not reformat files you didn't otherwise touch.

3. **Proof of no new failures.** I need the actual list, not a summary:
   a. With your changes: `pytest -q -p no:cacheprovider -rfE 2>&1 | grep -E '^(FAILED|ERROR)' | sort > /tmp/after.txt`; report counts line.
   b. Baseline: `alembic downgrade 0043_backfill_personal_teams`, `git stash -u`, run the same command into
      `/tmp/before.txt`, then `git stash pop`, `alembic upgrade head`. Confirm `git status` shows all your files back.
   c. Report `comm -13 /tmp/before.txt /tmp/after.txt` (tests failing only with your change). If any appear, investigate:
      if it's flaky (re-run that test alone on both trees), say so; if it's real, fix it.
   d. Report the final `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_unit.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py` result.
