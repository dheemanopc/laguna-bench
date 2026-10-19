# Work order 1 — fix `memory_not_accessible` when referencing your own memory

## Bug
A user writes memory M1, `memory_get(M1)` returns it, but writing M2 with
`references=[{target_uuid: M1, reference_kind: "cites"}]` fails with `memory_not_accessible`.
Reproduces for accounts provisioned by raw SQL (tenant + personal team + owner row in
`team_role_assignments` + primary identity — the way migration 0026 backfilled existing users),
NOT via `mem_mcp.teams.assignments.assign_role`.

Failing repro (already in tree, must pass, do not modify it):
`tests/integration/test_references_own_memory_repro.py`

## Root cause (already diagnosed — verify, then fix)
Memory-level access for the references machinery is decided **only** by
`user_effective_team_access` (UETA) for the memory's `team_id`. UETA is a cache table that is
only populated by the Python sync-refresh path (`assign_role` → `sync_refresh_on_user_assignment`)
or the periodic reconciler job. Raw-SQL-provisioned users have no UETA row, so the check fails —
even though the read path (`memory_get` by id: `tenant_tx` + `WHERE tenant_id = caller`) lets the
owner read their own memory. The rule ignores ownership. (Also note: when the target's `team_id`
is NULL the current check skips access entirely, which lets anyone reference another tenant's
team-less memory — the new rule closes that too.)

The same faulty rule ("access to memory X ⇔ UETA row for X.team_id") is evaluated at **four**
memory-id-based sites:
1. `src/mem_mcp/teams/references.py::resolve_reference_target` (write-time validation; used by
   `mcp/tools/write.py`).
2. `src/mem_mcp/teams/references.py::check_hard_delete_with_filtered_citers` (per-citer filter).
3. `src/mem_mcp/mcp/tools/refs_in.py` (filters citing/source memories).
4. `src/mem_mcp/mcp/tools/refs_out.py` (filters targets; currently uses `memory_references.target_team_id`).

## Required fix
Introduce ONE domain helper in `src/mem_mcp/teams/references.py` that defines memory-level access
for the references machinery and use it at all four sites. Correct rule:

> caller can access memory M  ⇔  M exists AND ( M.tenant_id = caller
>                                             OR (M.team_id IS NOT NULL AND a UETA row exists for (caller, M.team_id)) )

Suggested shape (adapt names to house style):
```python
async def caller_can_access_memory(conn, *, caller_user_id: UUID, memory_id: UUID) -> bool
```
implemented as a single `SELECT EXISTS(...)` query over `memories` + `user_effective_team_access`.
Do not filter `deleted_at` inside this helper (resolve_reference_target keeps its own
`deleted_at IS NULL` lookup); it is purely the access predicate.

Site specifics:
- `resolve_reference_target`: keep both resolution paths (uuid and slug-tuple) and their row
  lookups; replace the UETA-only check with the new rule (you may fold it into the lookup query, e.g.
  select `tenant_id` too, or call the helper). Both "not found" and "no access" must keep raising the
  identical `ReferenceTargetNotFoundError("reference target not found or not accessible")`. Update
  the docstring to describe the new rule.
- `check_hard_delete_with_filtered_citers`: a citer is accessible per the new rule on the citer
  (source) memory.
- `refs_in.py`: accessible per the new rule on each source memory (missing source → inaccessible,
  as today).
- `refs_out.py`: accessible per the new rule on each **target memory** (`target_memory_id`), not on
  `target_team_id` alone.
- Tools stay thin: the SQL lives in the domain module (CONVENTIONS.md "Layering").

## Do NOT change
- Slug-based team-level gates that run before the target is known: `mcp/tools/slug_lookup.py`,
  `memory_get` by slug (`mcp/tools/get.py`), `memory_get_batch` slug path (`mcp/tools/get_batch.py`).
  Those intentionally gate on UETA for the team to prevent slug enumeration — leave them.
- The opaque error envelope in `write.py` (`code: memory_not_accessible`, same message/data).
- Existing tests: do not modify or delete any.
- No migration is needed for this approach; don't add one.

## Tenant-scope linter
`tools/lint_tenant_scope.py` is run on `src/` by
`tests/unit/test_lint_tenant_scope.py` (`test_real_codebase_is_clean`). The new cross-tenant query
over `memories` is intentionally cross-tenant (it compares `tenant_id` to the caller inside the
predicate); if the linter flags it, use the existing exemption mechanism with a justification
comment, the same way the existing cross-tenant queries in `references.py` / `refs_in.py` are handled.
Check how those are currently exempted before choosing.

## Regression tests to add (new file(s); docstrings name the bug)
Add e.g. `tests/integration/test_references_access_rule.py` (use UUID-suffixed emails/team names,
clean up or use a rolled-back transaction; provision the "backfill-style" user with raw SQL exactly
like the repro does — NO `assign_role`, so no UETA row). Cover:
1. `resolve_reference_target`: own memory, no UETA row → resolves OK.
2. `resolve_reference_target`: another tenant's memory in a team the caller has no access to →
   `ReferenceTargetNotFoundError` with exactly the same message as for a random nonexistent UUID.
3. `resolve_reference_target`: another tenant's memory whose `team_id` IS NULL → rejected (opaque).
   (If the memories schema forbids NULL team_id, skip this case and say so.)
4. Cross-tenant memory where caller DOES have team access (via `assign_role`) → still resolves OK.
5. `check_hard_delete_with_filtered_citers`: backfill-style user, citer memory owned by caller with
   no UETA row → appears in `accessible_citers`; a stranger's citer in a stranger team is counted in
   `inaccessible_count` only.
6. `memsys_refs_in` and `memsys_refs_out` tools (build a `ToolContext` like other tool tests do; see
   CONVENTIONS.md "Tests") for a backfill-style user: own source/target memories are listed as
   accessible; a stranger's memory is counted as inaccessible and its UUID not exposed.
7. End-to-end through the plugin SDK (`sdk_client_factory`) for a backfill-style user: citing
   *another tenant's* memory (no team access) raises `PluginValidationError` with
   `code == "memory_not_accessible"`, and the error is identical to citing a random UUID.

## Acceptance / verification — report exact output
1. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py` → passes.
2. Your new test file(s) → pass.
3. `pytest -q -p no:cacheprovider tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py tests/unit/test_spec2_slug_lookup.py` → pass.
4. Full suite: **first** run `git stash` + `pytest -q -p no:cacheprovider tests` to record the
   baseline failure list, then `git stash pop` and run it again. Report both failure lists and confirm
   no new failures. (Be careful that `git stash` includes untracked files only if you use `-u`; make
   sure your new files are restored afterwards.)
5. `ruff check src tests` and `mypy` → clean (or no new errors vs baseline; report).

Report: files changed, test commands with pass/fail counts, the baseline vs after failure lists,
and anything uncertain.
