# Work order 2 — review fixes for order 1

The overall design is accepted. Please make these changes.

## 1. Migration `0035_2026_06_01_user_can_read_memory.py`
- Remove `AND m.deleted_at IS NULL` from `user_can_read_memory`. The rule must mirror the read path, and
  neither the `memories_select` RLS policy nor `memory_get` by id filter on `deleted_at`. With the filter,
  a caller's own soft-deleted citer is counted as "inaccessible" in
  `check_hard_delete_with_filtered_citers` / `memsys_refs_in`, and that is a behaviour change.
  `resolve_reference_target` already filters `deleted_at IS NULL` in its own lookup, so
  write-time behaviour does not change. Update the docstrings in the migration and in
  `caller_can_read_memory` (which currently says "deleted_at IS NULL") to match.
- The docstring cites "incident #17-references-own-memory", which is not a real reference. Describe the
  symptom and root cause without inventing an id. Fix the "underling" typo.
- Because 0035 is not committed anywhere, edit it in place, then run `alembic downgrade -1 && alembic upgrade head`
  (or otherwise make sure the DB function matches the file) and confirm with
  `SELECT pg_get_functiondef('user_can_read_memory(uuid,uuid)'::regprocedure)`.

## 2. Regression test file
Rename `tests/integration/test_user_can_read_memory_regression_01a54.py` to
`tests/integration/test_references_access_regression.py`, and tighten it:
- Use `pytest.raises(ReferenceTargetNotFoundError)` / `pytest.raises(HardDeleteBlockedError)` /
  `pytest.raises(PluginValidationError)` instead of try/except. Never use `except Exception`.
  For hard-delete, assert on the attributes (`exc.value.accessible_citers == [source_id]`,
  `exc.value.inaccessible_count == 0`, or `== []` and `== 1` for the outsider case) instead of the message text.
- Opacity: for both the helper and the write path, assert that the no-access error and the random-UUID
  error are **identical**: same `str(exc)` for the helper; for the SDK, same `code` and same `message`
  (and the same `details`/data if `PluginValidationError` exposes it).
- `content_hash` must be unique: use `f"hash-{uuid4().hex}"`.
- Add the missing cases from order 1:
  a. `resolve_reference_target` by slug tuple for the caller's own memory (backfill-provisioned user,
     no UETA). Use `insert_slug_with_retry` as in `tests/unit/test_references_helpers.py`. Clean up `slugs`.
  b. SQL function: team-visibility path (outsider gets an active `team_members` row for the owner's team
     → true; `status` not active → false) and UETA path (insert a `user_effective_team_access` row for
     (outsider, owner_team) → true). Look at the `team_members` schema in migrations for the required columns.
  c. SQL function: a soft-deleted memory owned by the caller → true (this pins the point-1 fix).
  d. `memsys_refs_in`: the target is owned by A, there is one citer by A and one citer by an unrelated
     tenant B (insert the reference rows directly with `insert_reference`) → `accessible_count == 1`,
     `inaccessible_count == 1`, and B's source UUID does not appear in `refs`.
  e. `memsys_refs_out`: the source is owned by A and cites A's memory plus B's memory (insert directly)
     → 1 accessible, 1 inaccessible, and B's UUID is not listed.
  f. A regression check that existing UETA-based cross-tenant access still works through
     `resolve_reference_target`: tenant B is given access to A's team through `assign_role` (as in
     `tests/unit/test_references_helpers.py`) → B can resolve A's memory.
- Make sure cleanup removes everything the tests create (slugs, team_members, UETA rows,
  memory_references, memories, assignments, identities, teams, tenants), including tenant rows.
  Write the cleanup so it runs even when an assertion fails.
- Run `ruff format` on the file. Some lines currently exceed 100 columns.

## 3. Verification (report exact commands and output summaries)
1. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_regression.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
2. Full suite **after**: `pytest -q -p no:cacheprovider tests`. Paste the final summary line and the full
   list of FAILED/ERROR test ids.
3. Full suite **baseline**: `git stash -u` (this also stashes the migration file, and the leftover DB function is harmless),
   run the full suite, paste the summary and the FAILED/ERROR ids, then `git stash pop`. After the pop, confirm
   `git status` shows the expected files. Report which failures are new; there should be none.
4. `ruff check src tests`, `ruff format --check src tests/integration/test_references_access_regression.py alembic/versions/0035_2026_06_01_user_can_read_memory.py`, `mypy`.
