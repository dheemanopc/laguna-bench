# Work order 3 — Rigorous baseline comparison (no code changes expected)

The code is in good shape. I need hard evidence that we introduced no new test failures. Do the following with
whatever command mechanism worked for you before (e.g. a Python `subprocess` wrapper). Do **not** change any
code unless step 3 finds a regression.

1. With the current changes in place, run `python -m pytest -q -p no:cacheprovider -rfE` and save the sorted list
   of FAILED/ERROR node ids to `/tmp/t5_after.txt`.
2. Get the baseline: run `git stash push -u` (this stashes the src changes, the migration and the new tests),
   check `git status` is clean, run the same pytest command and save the ids to `/tmp/t5_before.txt`. Then
   `git stash pop` and confirm with `git status` / `git diff --stat` that **all** changes are back (8 files: the
   migration, tool_descriptions.py, get.py, get_batch.py, update.py, write.py and the two new test files). The DB
   keeps the `revision` column during the baseline run; old code ignores it, so that's fine.
3. Report `diff /tmp/t5_before.txt /tmp/t5_after.txt`. Any test failing after but not before is a regression:
   investigate it. If it's flaky or order-dependent (e.g. duplicate-key failures from shared state), re-run that
   test file alone in both states. If it's real, fix it. Also re-run the full suite a second time after the
   changes to check that the counts are stable.
4. Delete the temporary wrapper files you created in `/tmp` (`/tmp/test_lint_typecheck.py`,
   `/tmp/test_alembic_roundtrip.py`) and make sure no stray files were left in the repo (`git status`).

Report the exact before/after counts, the diff, and the final `git status`.
