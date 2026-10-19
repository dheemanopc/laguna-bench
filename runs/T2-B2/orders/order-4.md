# Work order 4 — baseline comparison of full-suite failures (no code changes)

Your full run with the change gave `34 failed, 1042 passed, 31 skipped, 16 errors`. We need proof that none of
these are new. `git stash` was denied, so use a separate worktree of the baseline commit instead. Do NOT modify or
revert the working tree.

1. Save the failing/erroring ids from the run with the change:
   `pytest -q -p no:cacheprovider tests -rfE 2>&1 | grep -E '^(FAILED|ERROR) ' | sed 's/ - .*//' | sort > /tmp/after.txt`
   (use the scratch location you have write access to if /tmp isn't allowed.)
2. Baseline: `git worktree add <scratch>/baseline HEAD`, then from inside that worktree run the same pytest
   command, making sure the baseline's own `src` is the code under test, e.g.
   `cd <scratch>/baseline && PYTHONPATH=<scratch>/baseline/src pytest -q -p no:cacheprovider tests -rfE ...`
   Then verify which source got imported: `python -c "import mem_mcp, sys; print(mem_mcp.__file__)"` with the
   same PYTHONPATH. If the package is installed in editable mode and PYTHONPATH doesn't override it, say so and find a way
   that works (e.g. `python -I` won't help. Prefer `PYTHONPATH` first in sys.path, and check the printed path).
   Keep the DB at head 0035 (the function is additive; baseline code doesn't call it).
   Save to `/tmp/before.txt` (or scratch).
3. `comm -13 before after` (new failures) and `comm -23 before after` (fixed). Report both lists verbatim.
   Pay special attention to `tests/unit/test_spec2_slug_lookup.py` and anything that touches references,
   refs_in/refs_out, effective access, or slug lookups.
4. If any test is newly failing, investigate the root cause and report it (with the traceback excerpt). Don't fix
   anything yet unless it's clearly caused by our change. If so, describe the fix you'd make.
5. Remove the worktree afterwards (`git worktree remove <scratch>/baseline`) and confirm `git status --short` still
   shows the same 5 files.

Note: the suite shares one DB, so some tests may be flaky. If a test differs between runs, re-run that test
alone in both trees before calling it a regression.
