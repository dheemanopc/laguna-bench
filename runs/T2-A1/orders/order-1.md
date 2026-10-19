# Work order 1 — fix `memory_not_accessible` when referencing one's own memory

## Bug
A user writes memory M1, can read it with `memory_get(M1)`, but writing M2 with
`references=[{target_uuid: M1, reference_kind: "cites"}]` fails with
`memory_not_accessible`. Reproduces for users provisioned by raw SQL (tenant + personal team +
owner `team_role_assignments` row + primary `tenant_identities` row — exactly how migration 0026
backfilled existing users) instead of via the team-management API.

Failing repro (already in the tree, do NOT modify it):
`tests/integration/test_references_own_memory_repro.py`

## Root cause (already diagnosed — verify, then fix)
The references machinery decides "can the caller see memory X?" with a single rule:
"there is a `user_effective_team_access` (UEA) row for (caller, X.team_id)".
UEA is a *materialised cache* (migration 0023) that is only filled by
`teams/effective_access.py::sync_refresh_on_user_assignment` (called from `teams/assignments.py`
API paths) or by the periodic reconciler job (`jobs/refresh_team_access.py`). Raw-SQL provisioning
(and the 0026 backfill) inserts `team_role_assignments` directly, so no UEA row exists → the caller
is told their *own* memory is inaccessible.

The read path disagrees: `memory_get` by id (`mcp/tools/get.py`) runs under `tenant_tx` and returns
the row when `memories.tenant_id = caller` (plus the `memories_select` RLS policy, migration 0033:
`tenant_id = GUC OR (visibility='team' AND team_id = ANY(current_user_active_team_ids()))`).
Ownership never consults UEA.

The faulty UEA-only per-memory rule is evaluated in **four** places — all must be fixed and behave
identically:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (write-time validator used by
   `mcp/tools/write.py`; both the UUID path and the slug-tuple path — in the slug-tuple path the
   target row is resolved first and then access-checked, so it uses the same per-memory rule).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (citer filtering —
   my own citers are currently counted as "inaccessible").
3. `src/mem_mcp/mcp/tools/refs_in.py` (filters inbound citers by UEA on the source's team).
4. `src/mem_mcp/mcp/tools/refs_out.py` (filters outbound targets by UEA on `target_team_id`).

**Do NOT change** the team-level slug gates that run *before* the target is known — they are
intentional anti-enumeration gates: `mcp/tools/slug_lookup.py`, `mcp/tools/get.py` slug path,
`mcp/tools/get_batch.py` slug path. Leave `write_async.py`'s existence probe alone too.

## Required fix
### 1. One canonical DB-side predicate (new Alembic migration)
Create `alembic/versions/0035_2026_06_01_memory_readable_by.py` (revision
`"0035_memory_readable_by"`, `down_revision = "0034_safe_current_tenant_id"`), following the style of
0033/0034 (docstring explaining *why* — this incident; `op.execute(sa.text(...))`; a `downgrade()`
that drops the function).

Define a `LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public` function, e.g.

```sql
CREATE OR REPLACE FUNCTION memory_readable_by(p_memory_id uuid, p_user_id uuid DEFAULT NULL)
RETURNS boolean ...
AS $$
    SELECT EXISTS (
        SELECT 1 FROM memories m
        WHERE m.id = p_memory_id
          AND m.deleted_at IS NULL
          AND (
                m.tenant_id = COALESCE(p_user_id, safe_current_tenant_id())
             OR EXISTS (
                    SELECT 1 FROM user_effective_team_access uea
                     WHERE uea.user_id = COALESCE(p_user_id, safe_current_tenant_id())
                       AND uea.resource_team_id = m.team_id
                )
          )
    )
$$;
```
- Owner clause first (agrees with `memory_get`); team clause keeps the existing cross-team sharing
  semantics (a reference may legitimately target another tenant's memory the caller has team access to).
- When `p_user_id` is NULL fall back to `safe_current_tenant_id()` (NULLIF-guarded GUC — never a bare
  `current_setting(...)::uuid` cast). NULL user ⇒ returns false (no crash).
- `GRANT EXECUTE ON FUNCTION memory_readable_by(uuid, uuid) TO mem_app` (check how 0034 grants;
  PUBLIC is acceptable if that's the established pattern).
- Run `alembic upgrade head` against the test DB (`MEM_MCP_DB_MAINT_DSN` is set) and confirm
  `alembic downgrade -1 && alembic upgrade head` works.

### 2. Domain helper in `teams/references.py`
Add a single Python entry point used by every site, e.g.
`async def accessible_memory_ids(conn, *, memory_ids: Sequence[UUID], caller_user_id: UUID) -> set[UUID]`
(batch, one query: `SELECT id FROM unnest($1::uuid[]) AS id WHERE memory_readable_by(id, $2)`), and a
thin `memory_accessible_to(conn, *, memory_id, caller_user_id) -> bool` if convenient.
Update the module docstring / function docstrings that currently say access is enforced "via
user_effective_team_access" to describe the new rule and why (cache lag / raw-SQL provisioning).

### 3. Use it at all four sites
- `resolve_reference_target`: keep resolution as is (UUID or slug tuple → row), then gate with the
  helper. Not-found and no-access must still raise the **same** `ReferenceTargetNotFoundError`
  with the same message. Note the current code skips the access check when `team_id IS NULL` — the
  new predicate handles that case uniformly (owner can reference; non-owner without team can't); do
  not keep a bypass.
- `check_hard_delete_with_filtered_citers`: classify citers with the helper (by `source_memory_id`).
- `refs_in.py` / `refs_out.py`: classify by `source_memory_id` / `target_memory_id` respectively
  via the domain helper (move the filtering SQL out of the tool into `teams/references.py`, per the
  layering rule — tools stay thin). Output shape and counts semantics unchanged. A deleted or
  missing citer/target counts as inaccessible, as today.
- Run `ruff check src tests`, `mypy`, and the tenant-scope lint test
  (`tests/unit/test_lint_tenant_scope.py`) — if the linter flags new cross-tenant queries, add them to
  the exempt list with a justification comment like the existing entries.

### 4. Regression tests (new files; do not edit existing tests)
Name the bug in docstrings. Use UUID-suffixed emails/team names and clean up (see the repro file's
`_provision_user_like_backfill` / `_cleanup` for a raw-SQL provisioned user — reuse that pattern;
no UEA rows exist for such a user). Cover, at minimum:
- `resolve_reference_target` for a raw-SQL user's own memory: UUID path succeeds; slug-tuple path
  succeeds (insert a slug via `teams.slugs.insert_slug_with_retry`); memory with `team_id` NULL
  owned by caller succeeds.
- Cross-tenant still rejected: another tenant's memory with no team access → same
  `ReferenceTargetNotFoundError` with identical message as a random UUID. Through the tool/SDK, the
  envelope for no-access must equal the envelope for a nonexistent UUID (same code
  `memory_not_accessible`, same message/data apart from nothing).
- Cross-tenant *with* UEA access still succeeds (insert UEA row via `upsert_effective_access` or
  `assign_role`).
- `check_hard_delete_with_filtered_citers`: raw-SQL user's own citer is in `accessible_citers`,
  `inaccessible_count == 0`; a foreign-tenant citer without access is counted as inaccessible.
- `RefsInTool` / `RefsOutTool` (build `ToolContext` per CONVENTIONS.md tests section): own
  citer/target is listed as accessible for a raw-SQL user; foreign-no-access one is counted only.
- The SQL function directly: owner → true, foreign no-access → false, deleted → false, NULL user
  with no GUC → false (no exception).
- End-to-end via `sdk_client_factory` beyond the repro if cheap (e.g. slug-tuple reference to own memory).

## Acceptance
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py` passes.
- New regression tests pass.
- `pytest -q -p no:cacheprovider tests` — report the exact pass/fail counts, and list the failing
  test ids. Then run `git stash` / compare against the baseline (or otherwise determine) which
  failures pre-existed; there must be no new failures. Report the baseline failing ids too.
- `ruff check src tests` and `mypy` clean (or no new findings vs baseline — report).
- No existing test modified, skipped or deleted.

Report: files changed, exact commands + results, anything uncertain.
