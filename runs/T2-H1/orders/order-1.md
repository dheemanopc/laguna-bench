# Work order 1 — fix `memory_not_accessible` when referencing one's own memory

Read `CLAUDE.md` and `CONVENTIONS.md` first and follow them.

## Bug

A user whose account was provisioned via raw SQL (tenant + personal team + owner row in
`team_role_assignments` + primary `tenant_identities` row — exactly how migration 0026's backfill
provisioned all existing users) can write memory M1 and read it with `memory_get`, but writing M2 with
`references=[{target_uuid: M1, reference_kind: "cites"}]` fails with `memory_not_accessible`.
Failing repro (already in tree, must pass, do NOT modify it):
`tests/integration/test_references_own_memory_repro.py`.

## Root cause (already diagnosed — verify, then fix)

The read path decides visibility of a memory with the `memories_select` RLS policy
(`alembic/versions/0033_...`):
`tenant_id = <caller> OR (visibility = 'team' AND team_id = ANY(current_user_active_team_ids()))`
(`memory_get` / `memory_get_batch` by UUID additionally filter `tenant_id = caller`).

The references machinery instead uses a *memory-level* access check that only consults the
materialised `user_effective_team_access` (UETA) table:
`SELECT 1 FROM user_effective_team_access WHERE user_id = $1 AND resource_team_id = <memory's team>`.
UETA is only populated by the team-management API (`teams/assignments.py::assign_role` →
`teams/effective_access.py::sync_refresh_on_user_assignment`) or the refresh job. Raw-SQL-provisioned
users (incl. everyone backfilled by 0026) have no UETA row for their own personal team, so the check
denies them access to memories they own.

That same faulty rule is evaluated at FOUR places, all of which must be fixed consistently:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (write-time validator; used by
   `mcp/tools/write.py`, and therefore by the async write drain and the plugin SDK).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (per-citer access filter:
   own citers are wrongly counted as "inaccessible").
3. `src/mem_mcp/mcp/tools/refs_in.py` (`memsys_refs_in`: filters inbound citers by UETA on the source
   memory's team — own citers wrongly hidden).
4. `src/mem_mcp/mcp/tools/refs_out.py` (`memsys_refs_out`: filters outbound targets by UETA on
   `target_team_id` — own targets wrongly hidden).

## Required fix

Introduce ONE shared memory-level access rule, "can user U read memory M", and use it at all four sites.
The rule is: memory M exists AND
- `M.tenant_id = U` (owner — mirrors the read path), OR
- `M.visibility = 'team' AND M.team_id` is in U's active `team_members` teams (mirrors
  `current_user_active_team_ids()` in the `memories_select` policy), OR
- a UETA row exists for `(U, M.team_id)` (keep the existing cross-team grant so team-shared /
  cross-tenant references that work today keep working).

Implementation:
- New Alembic migration `alembic/versions/0035_2026_06_01_user_can_read_memory.py`
  (`revision = "0035_user_can_read_memory"`, `down_revision = "0034_safe_current_tenant_id"`), docstring
  explaining the incident/why (as the other migrations do). It creates
  `user_can_read_memory(p_user_id uuid, p_memory_id uuid) RETURNS boolean`,
  `LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public`, implementing the rule above
  with explicit parameters (it must work on connections with no tenant GUC — the domain helpers run
  under `system_tx` and existing tests call them on raw connections). Do not read the GUC inside it;
  if you do touch a GUC anywhere, use `safe_current_tenant_id()` / NULLIF. Return false (not NULL)
  for unknown memory / NULL inputs. `GRANT EXECUTE ... TO mem_app`. Provide `downgrade()` dropping it.
  Apply with `alembic upgrade head`.
- In `src/mem_mcp/teams/references.py`, add a public domain helper, e.g.
  `async def caller_can_read_memory(conn, *, caller_user_id: UUID, memory_id: UUID) -> bool`
  that calls the SQL function. Use it in `resolve_reference_target` (keep the existing
  `deleted_at IS NULL` lookups and the identical opaque `ReferenceTargetNotFoundError` message for both
  not-found and no-access) and in `check_hard_delete_with_filtered_citers` (per citer `source_memory_id`).
  Update docstrings/comments that say access is via UETA.
- `refs_in.py` / `refs_out.py`: replace the UETA queries with the shared helper on the source memory
  (refs_in) / target memory (refs_out). Tools stay thin — no inline access SQL.
- If you discover any other place where *memory-level* access for the references machinery is decided
  by UETA alone, fix it the same way and tell me. Grep for `user_effective_team_access` under `src/`.

## Do NOT change
- Slug-based, team-level gates that run before the target is known: `memsys_slug_lookup`
  (`mcp/tools/slug_lookup.py`), `memory_get` slug path, `memory_get_batch` slug path. They gate on UETA
  on purpose (anti slug-enumeration). Leave them byte-for-byte.
- Note: `resolve_reference_target` with a slug tuple resolves the memory first and then applies the
  memory-level check — that one SHOULD use the new rule.
- Cross-tenant protection: referencing another tenant's memory with no team access must still raise
  the same opaque error (write tool: same `-32602` + `data.code == "memory_not_accessible"` envelope,
  identical for not-found and no-access).
- Do not modify existing tests. Do not weaken anything.

## Regression tests to add (new files; UUID-suffixed names; clean up)
Use raw-SQL provisioning like the repro's `_provision_user_like_backfill` (no `assign_role`, so no UETA
rows). Name the bug in docstrings. Cover each changed site:
- `resolve_reference_target`: own memory resolves for a backfill-provisioned user (by UUID and by slug
  tuple); another tenant's memory with no team access → `ReferenceTargetNotFoundError` with the same
  message as a random UUID.
- `check_hard_delete_with_filtered_citers`: own citer appears in `accessible_citers`; a citer belonging
  to an unrelated tenant counts in `inaccessible_count` and its UUID is not exposed.
- `memsys_refs_in` and `memsys_refs_out` tools (build `ToolContext` per CONVENTIONS or use existing
  fixtures): own refs are listed as accessible; refs to/from an unrelated tenant's memory are counted
  inaccessible and not listed.
- Write path end-to-end (tool or `sdk_client_factory`): citing another tenant's memory still fails
  with `memory_not_accessible`, with the same envelope as citing a random non-existent UUID.
- The SQL function directly: owner → true; outsider → false; team-visibility via `team_members` → true;
  UETA grant → true; unknown memory → false.

## Verification (report exact commands + results)
1. `alembic upgrade head`
2. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py` — must pass.
3. Your new tests + `tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
   and any existing refs_in/refs_out/slug tests.
4. Full suite `pytest -q -p no:cacheprovider tests` BEFORE your change (git stash) and AFTER, and list
   failing test ids in both runs so I can confirm no new failures. (Remember to re-run
   `alembic upgrade head` as needed; downgrade isn't necessary for the baseline — the extra function is
   harmless.)
5. `ruff check src tests`, `ruff format --check` on changed files, `mypy`, and the tenant-scope linter
   test (`tests/unit/test_lint_tenant_scope.py`). If the linter flags new cross-tenant `memories`
   queries, follow its exempt-list convention with a justification comment.
