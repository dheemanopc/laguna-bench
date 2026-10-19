# Work order 1 — fix "memory_not_accessible" when referencing one's own memory

## Symptom
`tests/integration/test_references_own_memory_repro.py` (already in the tree, do NOT modify) fails:
a user provisioned via raw SQL (tenant + personal team + owner `team_role_assignments` row + primary
identity — no team-management API) writes M1, reads it with `memory_get`, then writing M2 with
`references=[{target_uuid: M1, reference_kind: "cites"}]` raises `memory_not_accessible`.

## Root cause (already diagnosed — implement this fix)
Every access check in the references machinery uses the rule
"caller has a row in `user_effective_team_access` (UETA) for the memory's `team_id`".
UETA is only populated by the Python sync refresh (`mem_mcp.teams.effective_access`, called by
`assign_role`) and the reconciler job — so raw-SQL-provisioned users have no UETA rows, and the rule
denies them even their OWN memories. The read path (`memories_select` RLS policy, migration 0033, and
`memory_get` which filters `tenant_id = caller`) always lets the owning tenant see its memories.
The rule is also sloppy in `resolve_reference_target`: when `team_id IS NULL` it skips the access check
entirely (any caller can reference any null-team memory of any tenant).

The faulty rule is evaluated in four places — fix ALL of them consistently:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (write-time; used by `mcp/tools/write.py`,
   and thus by the plugin SDK `sdk.write(references=...)` and the async-write drain).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (per-citer access).
3. `src/mem_mcp/mcp/tools/refs_in.py` (per-source-memory access).
4. `src/mem_mcp/mcp/tools/refs_out.py` (currently checks `target_team_id` of the edge; should check the
   target memory itself).

## Fix
### A. New Alembic migration with a single DB-side helper
`alembic/versions/0035_2026_06_01_memory_accessible_to.py`, `revision = "0035_memory_accessible_to"`,
`down_revision = "0034_safe_current_tenant_id"` (verify that's the current head). Docstring at top explains
the why (this incident), like the existing migrations. SQL via `op.execute(sa.text(...))`.

```sql
CREATE OR REPLACE FUNCTION memory_accessible_to(p_user_id uuid, p_memory_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM memories m
        WHERE m.id = p_memory_id
          AND p_user_id IS NOT NULL
          AND (
                m.tenant_id = p_user_id                       -- owner: mirrors memories_select / memory_get
                OR (
                    m.team_id IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM user_effective_team_access uea
                        WHERE uea.user_id = p_user_id
                          AND uea.resource_team_id = m.team_id
                    )
                )
          )
    )
$$;
GRANT EXECUTE ON FUNCTION memory_accessible_to(uuid, uuid) TO mem_app;
```
It takes the user explicitly (callers run under `system_tx`, no GUC), so there is no GUC read; if you
add any GUC fallback it must use `safe_current_tenant_id()` / NULLIF. It does NOT filter `deleted_at` —
callers keep their own deletion filters. `downgrade()` drops the function. Apply with `alembic upgrade head`.

### B. Use the helper at all four sites
1. `resolve_reference_target`: fold the access check into the resolution query so not-found and no-access
   take the SAME single query and raise the SAME `ReferenceTargetNotFoundError` message, e.g.
   `SELECT id, team_id FROM memories WHERE id = $1 AND deleted_at IS NULL AND memory_accessible_to($2, id)`
   (and the equivalent for the slug-tuple path: `... AND memory_accessible_to($4, m.id)`). Remove the
   `team_id IS NULL → skip check` hole. Update the docstring (access rule = owner OR team access).
2. `check_hard_delete_with_filtered_citers`: per-citer access = `memory_accessible_to(caller, source_memory_id)`
   (can be computed in the same SELECT as a boolean column instead of N extra queries). Keep the
   filtered-citer/inaccessible_count semantics.
3. `refs_in.py`: access for each inbound edge = `memory_accessible_to(ctx.tenant_id, source_memory_id)`
   (a missing source memory counts as inaccessible, as today).
4. `refs_out.py`: access for each outbound edge = `memory_accessible_to(ctx.tenant_id, target_memory_id)`.
Prefer putting the SQL in the domain module (`teams/references.py`, e.g. a small
`memory_accessible_to(conn, *, user_id, memory_id) -> bool` wrapper or filtered variants of
`get_inbound_refs`/`get_outbound_refs`) per CONVENTIONS.md layering, but don't over-engineer.

### Do NOT change
- Slug lookups that gate at the team level before the target is known: `mcp/tools/slug_lookup.py`,
  the slug path of `mcp/tools/get.py`, the slug path of `mcp/tools/get_batch.py`. Leave them alone.
- `write_async._check_references_exist` (existence-only probe; access is enforced at drain via the resolver).
- Any existing test. Don't weaken/skip anything.
- Error envelopes: write.py's opaque `memory_not_accessible` envelope must stay byte-identical.

Make sure `tools/lint_tenant_scope.py` stays clean (`tests/unit/test_lint_tenant_scope.py`) — if a new
cross-tenant `memories` query needs an exemption, follow the existing justification-comment pattern.

## Regression tests (new files only)
Add `tests/integration/test_references_owner_access.py` (use `pg_pool`, `sdk_client_factory`, provision
users via raw SQL like the repro's `_provision_user_like_backfill` — i.e. NO UETA rows — and clean up after).
Cover at least:
1. `resolve_reference_target` on own memory with no UETA row → succeeds (UUID path AND slug-tuple path;
   for slug, insert a `slugs` row or write a `decision` with `slug_clue`).
2. Cross-tenant: tenant B (no team access) referencing tenant A's memory → `ReferenceTargetNotFoundError`
   with message identical to a random-UUID miss; via SDK → `PluginValidationError` code
   `memory_not_accessible` with identical message to a miss.
3. Cross-tenant memory with `team_id IS NULL` is NOT referenceable by another tenant (if the schema allows
   null team_id — check constraints; skip this case only if it's impossible to construct).
4. Team access still works: tenant B granted access via `assign_role` (which fills UETA) can reference
   tenant A's team memory.
5. `check_hard_delete_with_filtered_citers`: own citer memories (no UETA) appear in `accessible_citers`;
   a stranger's citer is counted in `inaccessible_count`.
6. `sdk.refs_in` / `sdk.refs_out` (or the tool classes directly) for a raw-SQL-provisioned user: own
   edges are returned; an edge to/from an inaccessible other-tenant memory is filtered out.
7. Deleted target (`deleted_at` set) is still rejected opaquely.

## Verification — run and report exact results
- `alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py`
- `pytest -q -p no:cacheprovider tests/integration/test_references_owner_access.py tests/integration/test_references_integration.py tests/integration/test_plugin_memory_client_it08.py tests/unit/test_references_helpers.py tests/unit/test_lint_tenant_scope.py`
- Full suite: `pytest -q -p no:cacheprovider tests` — BEFORE your change too (e.g. `git stash` first, or
  compare against a baseline run) so you can list which failures are pre-existing vs new. Report the
  failing test ids in both runs.
- `ruff check src tests` and `mypy`.
Report: files changed, test results (pass/fail counts, failing ids), anything uncertain.
