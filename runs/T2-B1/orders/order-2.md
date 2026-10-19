# Work order 2 — follow-ups on the `memory_readable_by` fix

Good work on order 1; the design is right. Please make these changes:

## 1. Remove the stray baseline file
`.bench_baseline.txt` is added (and staged) at the repo root. Remove it from the index and the working
tree (`git rm -f .bench_baseline.txt` or `git rm --cached` + delete). Keep any notes outside the repo.
Do not commit anything.

## 2. Don't filter soft-deleted rows inside the predicate
`memory_readable_by` currently requires `m.deleted_at IS NULL`. That makes the predicate disagree with
the read path (`memory_get` by id returns the caller's soft-deleted memories too — no `deleted_at`
filter) and changes `memsys_refs_in` / `memsys_refs_out` / `check_hard_delete_with_filtered_citers`
behaviour: a caller's own soft-deleted citer would now be reported as "inaccessible" (previously the
check was purely access-based). Make the function a pure *access* predicate (exists AND (owner OR UEA
share)); `resolve_reference_target` already excludes deleted targets in its own lookup query, so its
behaviour is unchanged. Since 0035 is not released, edit migration 0035 in place, then re-apply
(`alembic downgrade -1 && alembic upgrade head`). Update the docstrings (migration, `references.py`
module docstring) and the `test_deleted_memory_not_readable` test accordingly — it's your own new
test, so change it to assert the new semantics (e.g. resolve_reference_target still rejects a deleted
target opaquely, while `can_read_memory` on the owner's soft-deleted memory is true).

## 3. Remove benchmark/work-order references from code
The migration docstring says "Per work order T2-B1" and `references.py` says "see T2-B1". Rephrase as
a plain incident description (e.g. "bug: memory_not_accessible when citing one's own memory for
raw-SQL-provisioned accounts").

## 4. Missing regression tests (add; don't modify existing pre-change tests)
Add to your test file(s) (integration tests may go in `tests/integration/`):
- **NULL-team memory, stranger**: `can_read_memory` false for a different tenant (even if that tenant
  has UEA rows on unrelated teams), and `resolve_reference_target` raises the opaque error.
- **`memsys_refs_in` tool** (call `RefsInTool()(ctx, RefsInInput(...))` with a ToolContext, see
  CONVENTIONS.md "Tests"): raw-SQL user (no UEA rows) with own M2 citing own M1 → `refs_in(M1)` has
  `accessible_count == 1`, `refs[0].source_memory_id == M2`, `inaccessible_count == 0`. Plus a
  foreign-tenant citer (another raw-SQL tenant's memory citing M1, inserted via `insert_reference`
  or raw SQL) → counted only in `inaccessible_count`, its id absent from `refs`.
- **`memsys_refs_out` tool**: own M2 → own M1 edge is accessible for the raw-SQL owner; an edge from
  M2 to a foreign-tenant memory with no access is only counted in `inaccessible_count`.
- **Write path, opaque cross-tenant rejection**: via `sdk_client_factory` (or `MemoryWriteTool`),
  referencing another tenant's memory with no team access fails with `code == "memory_not_accessible"`,
  and the error (code + message + data) is identical to referencing a random nonexistent UUID. Also
  assert no memory row was created for the rejected write if feasible.
- **Write path, cross-tenant WITH team access** still works: give tenant B a UEA row on tenant A's
  team (insert the UEA row directly, or use `teams/effective_access.upsert_effective_access` after
  inserting a `team_role_assignments` row) → B can cite A's memory.
All tests must use UUID-suffixed names and clean up their rows (including `memory_references`,
`user_effective_team_access`, `team_role_assignments`).

## 5. Verify and report exact results
- `alembic downgrade -1 && alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py <your test files> tests/integration/test_references_integration.py tests/unit/test_references_helpers.py tests/unit/test_lint_tenant_scope.py`
- Full suite `pytest -q -p no:cacheprovider tests` and compare failing ids against your earlier baseline
  list; for any test whose status differs from baseline (other than the repro), show it fails the same
  way with your source changes stashed, or explain.
- `ruff check src tests` and `ruff format --check` on touched files, `mypy`.
- `git status` at the end (must not show `.bench_baseline.txt`).
