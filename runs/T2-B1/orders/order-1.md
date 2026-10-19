# Work order 1 — fix `memory_not_accessible` when a user references their OWN memory

## Bug
A user writes memory M1, reads it back with `memory_get(M1)` fine, then writes M2 with
`references=[{target_uuid: M1, reference_kind: "cites"}]` → rejected with `memory_not_accessible`.
Reproduces for accounts provisioned by raw SQL (tenant + personal team + owner row in
`team_role_assignments` + primary identity), as the 0026 personal-team backfill did.
Failing repro (already in tree, do NOT modify it): `tests/integration/test_references_own_memory_repro.py`.

## Root cause (already diagnosed — verify, then fix)
Per-memory access checks in the references machinery consult ONLY the materialised table
`user_effective_team_access` (UEA). UEA is populated only by Python code paths
(`teams/effective_access.py` sync refresh from the team-management API, and the periodic
`jobs/refresh_team_access.py` reconciler). Raw-SQL provisioned users have no UEA row for their own
personal team, so the check fails. The read path does not depend on UEA: `memory_get` by id
(`mcp/tools/get.py`) returns any memory with `tenant_id = caller` (under `tenant_tx`/RLS).
So write-time/reference access disagrees with what the caller can read.

The faulty rule ("SELECT 1 FROM user_effective_team_access WHERE user_id=$1 AND resource_team_id=<memory's team>")
is evaluated per-memory in FOUR places — fix all of them, consistently:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (used by `mcp/tools/write.py`).
   Note it also currently SKIPS the access check entirely when the target's `team_id IS NULL`
   — that is a leak; the new rule must apply to such rows too (owner can, others cannot).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (per-citer check).
3. `src/mem_mcp/mcp/tools/refs_in.py` (per source memory).
4. `src/mem_mcp/mcp/tools/refs_out.py` (currently checks `target_team_id` of the edge; make it a
   per-target-memory check on `target_memory_id` using the same rule).

Do NOT change the slug-before-target team-level gates — they are intentional (anti slug-enumeration):
`mcp/tools/slug_lookup.py`, the slug path of `mcp/tools/get.py`, the slug path of `mcp/tools/get_batch.py`.
Leave `write_async.py`'s existence probe alone.

## Required design
Single source of truth for "can user U read memory M (for references purposes)":

    memory M exists AND M.deleted_at IS NULL AND (
        M.tenant_id = U                                   -- own memory: what memory_get allows
        OR (M.team_id IS NOT NULL AND EXISTS (SELECT 1 FROM user_effective_team_access
              WHERE user_id = U AND resource_team_id = M.team_id))   -- existing cross-team sharing, kept
    )

Implement it as:
- A new Alembic migration `alembic/versions/0035_2026_<MM>_<DD>_<slug>.py`
  (`revision = "0035_<slug>"`, `down_revision = "0034_safe_current_tenant_id"`), following the
  style of `0033`/`0034`: why-docstring, `op.execute(sa.text(...))`, a real `downgrade()`.
  It creates a `LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public` function, e.g.
  `memory_readable_by(p_memory_id uuid, p_user_id uuid) RETURNS boolean`, implementing the rule
  above, and `GRANT EXECUTE ... TO mem_app` (check how 0034 / 0016 grant). It takes the user
  explicitly because all callers run in `system_tx` (no tenant GUC). A NULL user must yield false.
  If you choose to let it default to the GUC, it must use `safe_current_tenant_id()` (never a bare cast).
  SECURITY DEFINER matters: under a mem_app connection without a GUC, RLS on `memories` would
  otherwise hide the row.
- A Python domain helper in `src/mem_mcp/teams/references.py` (e.g.
  `async def can_read_memory(conn, *, memory_id, user_id) -> bool` and/or a bulk variant) that calls
  the SQL function. All four sites above use it — no remaining per-memory UEA lookups in them.
- `resolve_reference_target`: keep the opaque contract — target missing, deleted, or not readable
  all raise the SAME `ReferenceTargetNotFoundError("reference target not found or not accessible")`.
  It still needs to return `{"memory_id", "team_id"}` for `insert_reference`. Keep the slug-tuple
  resolution path working (resolve slug → memory, then apply the same per-memory rule).
  Update docstrings/comments that describe the old UEA-only rule (incl. module docstrings and the
  NOTE paragraphs) so they describe the new rule.
- Keep `tools/lint_tenant_scope.py` clean (`tests/unit/test_lint_tenant_scope.py`); add exemptions with
  justification comments only if needed, following the existing pattern.

## Tests (add new; do NOT modify or delete existing tests)
Add regression tests (docstrings name the bug), using raw-SQL-provisioned users with UUID-suffixed
names (see the repro file for a provisioning helper; clean up afterwards). At least:
- Migration/helper: owner can read own memory with NO UEA row; other tenant without UEA cannot;
  other tenant WITH a UEA row on the memory's team can; deleted memory → false; nonexistent → false;
  NULL-team memory: owner true, stranger false.
- `resolve_reference_target`: own memory (no UEA) resolves; foreign tenant memory (no access) raises
  `ReferenceTargetNotFoundError` with the same message as a random nonexistent UUID.
- Write tool / SDK: own-memory reference succeeds (repro), cross-tenant reference with no team access
  still fails with the identical opaque envelope (`code == "memory_not_accessible"`, same message/data
  as for a nonexistent UUID).
- `check_hard_delete_with_filtered_citers`: citer that is the caller's own memory (no UEA) is counted
  in `accessible_citers`; a foreign-tenant citer is in `inaccessible_count`.
- `memsys_refs_in` and `memsys_refs_out`: for a raw-SQL user, own refs appear in `refs` /
  `accessible_count`; a foreign-tenant, no-access edge is counted only in `inaccessible_count`.
Look at `tests/integration/test_references_integration.py`, `tests/unit/test_references_helpers.py`,
and `tests/integration/conftest.py` (`sdk_client_factory`) for fixtures and patterns.

## Verification (report exact commands + results)
1. `alembic upgrade head` (MEM_MCP_DB_MAINT_DSN is set). Don't change env vars.
2. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py` → must pass.
3. Your new tests + `tests/integration/test_references_integration.py tests/unit/test_references_helpers.py tests/unit/test_lint_tenant_scope.py`.
4. Full suite BEFORE your change (git stash or note from first run) and AFTER:
   `pytest -q -p no:cacheprovider tests` — report the list of failing test ids both times so we can
   confirm no new failures.
5. `ruff check src tests` and `mypy` — clean for touched files.

Report: files changed, design summary, the exact test results, anything uncertain.
