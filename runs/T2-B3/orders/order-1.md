# Work order 1 — fix `memory_not_accessible` when referencing your own memory

## Symptom
A user provisioned via raw SQL (tenant + personal team + `team_role_assignments` owner row + primary
`tenant_identities` row — the way migration 0026's backfill provisioned all existing users) writes M1,
reads it fine with `memory_get`, but writing M2 with `references=[{target_uuid: M1, reference_kind: "cites"}]`
fails with `memory_not_accessible`. Failing repro (already in tree, do NOT modify it):
`tests/integration/test_references_own_memory_repro.py`.

## Root cause (already diagnosed — verify, then fix)
The references machinery decides "can the caller see memory X?" **only** by looking for a row in
`user_effective_team_access (user_id, resource_team_id = X.team_id)`. That table is a precomputed cache that is
only populated by the team-management API (`teams/effective_access.py::sync_refresh_on_user_assignment`) or the
periodic reconciler job. Users provisioned by raw SQL have no row, so the check rejects memories the caller
**owns**. The read path (`mcp/tools/get.py`, by id) instead allows any memory with `tenant_id = caller` (via
`tenant_tx` + RLS `memories_select`). The two rules disagree.

The same faulty rule (team-only gate keyed purely on `user_effective_team_access`) is evaluated in these places,
all of which must be fixed to use one shared rule:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (write-time validator; used by `mcp/tools/write.py`).
   Also note: when `row["team_id"] IS NULL` it currently skips the check entirely, so a cross-tenant memory with
   no team is accessible to anyone — the new rule must close that (null team ⇒ only the owning tenant).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (per-citer accessibility of the
   **source** memories).
3. `src/mem_mcp/mcp/tools/refs_in.py` (filters each inbound ref by access to the **source** memory).
4. `src/mem_mcp/mcp/tools/refs_out.py` (filters each outbound ref by access to the **target** memory; currently
   only uses `target_team_id` from the ref row — must evaluate against the target memory itself).

Do **NOT** change the slug-based, pre-resolution team-level gates — they are intentional (anti slug-enumeration):
`mcp/tools/slug_lookup.py`, the slug branch of `mcp/tools/get.py`, the slug branch of `mcp/tools/get_batch.py`.
Do not change `write_async.py::_check_references_exist` (existence probe only; access is enforced at drain via
`write.py`). Do not "fix" this by inserting `user_effective_team_access` rows or special-casing write.py.

## Required fix
Add ONE shared domain helper in `src/mem_mcp/teams/references.py`, e.g.

```python
async def caller_can_access_memory(conn, *, memory_id: UUID, caller_user_id: UUID) -> bool
```
Rule (memory must exist and `deleted_at IS NULL` where the call site previously required that — keep each call
site's existing deleted-row semantics; for resolve_reference_target the target must be non-deleted):
- `memories.tenant_id = caller_user_id`  (owner — matches what `memory_get` lets the caller read), **OR**
- `memories.team_id IS NOT NULL` AND a `user_effective_team_access` row exists for
  `(caller_user_id, memories.team_id)` (preserves existing cross-tenant team sharing).

Implement it as a single SQL query (`SELECT EXISTS (...)` / `SELECT 1 FROM memories m WHERE m.id = $1 AND
(m.tenant_id = $2 OR (m.team_id IS NOT NULL AND EXISTS (SELECT 1 FROM user_effective_team_access ...)))`).
Where a call site already fetched the memory row, it is fine to have a sibling helper that takes the row's
`tenant_id`/`team_id` instead of re-querying — but the rule must live in exactly one place (one predicate
function / one SQL fragment), and every one of the 4 sites must use it. Callers run under `system_tx`
(cross-tenant by design), so the SQL must filter explicitly as above; add the same "NOTE on tenant scoping"
style comment the module already uses if `tools/lint_tenant_scope.py` would flag it (run the linter — see below).

`resolve_reference_target` must keep the **opaque** contract: not-found, deleted, and no-access all raise the
same `ReferenceTargetNotFoundError("reference target not found or not accessible")`, so `write.py` keeps
returning the identical `memory_not_accessible` envelope. Fetch `tenant_id` along with `id, team_id` there.

A database-side helper is NOT required. If you do decide one is needed, it must be a new Alembic migration in
`alembic/versions/` following the 0033 conventions (`SECURITY DEFINER`, `SET search_path = public`,
NULLIF-guarded GUC reads, downgrade, why-docstring). Prefer the pure-Python/SQL-query approach.

Update docstrings in `references.py` (they currently say the check is "via user_effective_team_access") to
describe the new rule and why (owner always has access; cache may lack rows for SQL-provisioned users).

## Tests to add (new file(s); do not modify existing tests)
Add `tests/integration/test_references_access_rule.py` (reuse the raw-SQL provisioning approach from the repro
file — copy the helper; also look at `tests/integration/conftest.py` for `pg_pool`, `sdk_client_factory`, and
how other integration tests invoke MCP tools like `memsys_refs_in` / `memsys_refs_out` and
`check_hard_delete_with_filtered_citers`). Clean up all rows you create. Cover at least:
1. Raw-SQL-provisioned user cites own memory by UUID → succeeds (separate from the repro).
2. Raw-SQL-provisioned user cites own memory by slug tuple (if slugs are assigned on write for decision/fact
   — check how the slug path works; if the slug path requires team-level access up front by design, assert the
   current behaviour only if it's meaningful, otherwise skip this case and say so in the report).
3. Cross-tenant: user B (no team access to A's team) cites A's memory by UUID → rejected with
   `memory_not_accessible`, and the error envelope (code + message/data) is byte-identical to citing a random
   nonexistent UUID.
4. Cross-tenant with a `user_effective_team_access` row for A's team → citing succeeds (sharing preserved).
5. Cross-tenant memory with `team_id IS NULL` → rejected opaquely (if the schema allows a NULL team_id; if not,
   note it).
6. `memsys_refs_out` / `memsys_refs_in` for the raw-SQL user on their own M1/M2 → the ref is in `refs`
   (accessible_count 1, inaccessible_count 0); and for an outsider user B the same calls report it as
   inaccessible (count only, no UUIDs).
7. `check_hard_delete_with_filtered_citers` for the raw-SQL user on own target with own citer → citer appears
   in `accessible_citers`; for outsider → counted in `inaccessible_count`.
Also add focused unit tests for the helper if the repo has a unit-test pattern for `teams/references.py`.

## Verification (run and paste exact results in your report)
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py` → must pass.
- `pytest -q -p no:cacheprovider <your new test files>`
- `pytest -q -p no:cacheprovider tests` — BEFORE your change (`git stash` first, or run it first) and AFTER,
  and report the list of failing tests in both runs so we can confirm no new failures.
- `ruff check src tests`, `mypy`, and `python tools/lint_tenant_scope.py` (check how it is invoked) — report.

## Report
Files changed, the final rule and where it lives, each call site changed, test results (before/after failing
lists), anything uncertain.
