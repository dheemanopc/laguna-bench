# Work order 2 — small fixes + MANDATORY runtime verification

Your order-1 code changes look correct; keep the design. Last time you reported the Bash tool was denied,
so nothing was executed. This order is mainly about running things. Please try Bash again (plain commands
like `alembic upgrade head`, `pytest ...`, `ruff check ...`, `mypy`). If Bash is still unavailable, say so
explicitly in the first line of your report and do the code fixes anyway.

## Code fixes
1. `alembic/versions/0035_2026_06_01_memory_accessible_to.py`: the docstring's first line says "PL/pgSQL",
   but the function is `LANGUAGE sql`. Fix the wording. Also drop the "Incident WO-1" label (it's our
   internal order number). Describe it as the reference-access incident instead.
2. `tests/integration/test_references_owner_access.py`:
   - `test_null_team_memory_not_referenceable_cross_tenant`: `sdk_owner` is assigned but never used
     (ruff F841). Remove it, and the `sdk_client_factory` param if nothing else needs it.
   - `test_assign_role_team_access_still_resolves` commits its fixture and never cleans up. Wrap it in
     try/finally with `_cleanup(...)` like the other tests. Include `shared_team` in the teams list, and
     make sure `user_effective_team_access` rows are removed (they cascade on tenant/team delete, so that
     should already work, but verify).
   - Replace the "WO-1" labels in docstrings/comments with a neutral description.
   - Make sure lines fit the project's ruff line length (the `_cleanup` DELETE lines look too long).

## Verification (run these; report exact output summaries)
1. `alembic upgrade head` (then `alembic current` should show `0035_memory_accessible_to (head)`).
2. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py`
3. `pytest -q -p no:cacheprovider tests/integration/test_references_owner_access.py tests/integration/test_references_integration.py tests/integration/test_plugin_memory_client_it08.py tests/unit/test_references_helpers.py tests/unit/test_lint_tenant_scope.py tests/unit/test_spec2_slug_lookup.py`
4. Full suite with the change: `pytest -q -p no:cacheprovider tests`. Record the failing test ids.
5. Baseline for comparison: `git stash -u` (this stashes the new files too), run
   `pytest -q -p no:cacheprovider tests` again and record the failing test ids, then `git stash pop`.
   Leave the DB at head 0035; the old code doesn't call the new function, so the extra DB function is harmless
   for the baseline run. Confirm `git status` afterwards shows all 5 changed/new files restored.
6. `ruff check src tests` and `ruff format --check` on the files you touched (only if the repo uses
   ruff format; don't reformat unrelated files), plus `mypy`.

Report: the failing test ids for (4) and (5) and the diff between them (it must be empty, apart from tests
that newly pass), plus ruff/mypy results. If anything new fails, fix it and re-run.
