# Work order 2 — fixes from review of order 1

Good progress. Please fix the following; keep everything else as is.

## Bugs
1. **Node order in `mindmap_get`** (`src/mem_mcp/mcp/tools/mindmap_get.py`): you iterate `for mem_id in candidate_ids`
   (a `set`) — output order is random. Iterate `all_members` (already ordered by `added_at`) and skip members not in
   `candidate_ids`, so `nodes` and `resolved` keep membership order (root first). Add a test asserting order is stable
   (root first, then write order).
2. **`open_loops` on the `since` early-return** is `[]`. `open_loops` must always be computed over the full membership
   (status open + `responsible_party` ∈ {owner, model}, not root), regardless of `since`/`include`. Remove the
   duplicated early-return block — the normal path already yields empty `nodes`/`resolved`/`edges` when the candidate
   set is empty. Make sure `since` + nothing changed still returns `nodes == []`, `resolved == []`, `edges == []`
   and the same cursor (keep/extend the test).
3. **Stale docs about open_loops**: the `mindmap_get` module docstring and `TOOL_DESCRIPTIONS["mindmap_get"]` still say
   open_loops = `responsible_party == 'owner'` (twice in the description). Update them to the implemented rule:
   open (unsettled) branches carrying a whose-turn `responsible_party` (`owner` = waiting on the user, `model` = your
   turn); resolved/dropped branches never appear. Mention settling a branch via `mindmap_resolve`.

## Revert unrelated changes
4. In `service.py` revert your edits to `resolve_map_root` and `find_live_map_seeded_from` (the
   `isinstance(result, UUID)` wrappers) — out of scope and they change behaviour (e.g. under mocks). If mypy
   complains about returning Any, check whether it complained on the baseline too; if it did not, use a minimal
   `cast`/annotation instead.
5. Remove the empty `if TYPE_CHECKING: pass` blocks in `mindmap_get.py` and `mindmap_resolve.py`.

## Resolve tool polish (`mindmap_resolve.py`)
6. The self-settle error uses `data={"code": "memory_not_accessible"}` — wrong code. Use
   `data={"errors": [{"path": "resolved_by_memory_id", "message": "a node cannot settle itself"}]}`.
7. Do the self-settle check regardless of ordering subtleties (it's fine first) but ensure all -32602 paths leave
   nothing changed (they do, since the checks precede writes inside the tx — just confirm with tests, see 10).

## Migration
8. Name every constraint explicitly (spec asked for it): the inline CHECKs on `status`, `resolution_summary`,
   `resolved_by_party` are currently anonymous. Use `ADD COLUMN ... ` then `ADD CONSTRAINT <name> CHECK (...)`, e.g.
   `memory_map_membership_status_check`, `memory_map_membership_resolution_summary_len_check`,
   `memory_map_membership_resolved_by_party_check`, and rename `chk_status_settlement_consistent` to
   `memory_map_membership_settlement_consistent_check`. Downgrade drops them explicitly. Wrap long lines
   (follow the repo's line length; run `ruff check alembic/versions/0044*` and `ruff format --check` on your files if the
   project uses ruff format — match whatever the existing files do). Rename the migration file date to today's date
   in your environment if you like; keep revision id `0044_mindmap_branch_status`.
9. Actually prove the migration round trip: run `alembic upgrade head`, `alembic downgrade -1`, `alembic upgrade head`
   and paste the output in your report (after changing the migration you must re-apply it: downgrade then upgrade).

## Tests to add (new tests only; in your new files)
10. In `tests/integration/test_mindmap_branch_status.py`:
    - for the not-a-member / other-map / unknown-map / archived / root / self-settle error cases, assert *nothing
      changed*: the target node's status still `open`, no new `memory_references` row, no new `memory_map_events` row
      (compare `current_cursor` before/after). Include the case "node belongs to a DIFFERENT live map of the same
      tenant" explicitly.
    - `include="all"`: all members in `nodes`, settled ones with `status` resolved/dropped; open ones `open`.
    - `open_loops`: includes an open `responsible_party="owner"` node AND an open `responsible_party="model"` node;
      excludes a node without responsible_party; excludes them once resolved/dropped. Also check open_loops is
      populated on a `since` read with no changes.
    - `since` after a `mindmap_write_node` returns only the new node; after a `mindmap_link(..., map_key=...)` returns
      the source and target nodes; cursor strictly increases on each write/resolve; `MindmapResolveOutput.cursor`
      equals the cursor a subsequent `mindmap_get` reports.
    - resolve with resolver: edge in `memory_references` has `source_memory_id=resolver`, `target_memory_id=node`,
      `reference_kind='resolves-under'` (and `dropped-under` for dropped), and the event row has `event='resolve'`,
      `actor` = resolved_by_party.
    - re-settling (resolved → dropped) updates status/summary.

## Verify and report (exact outputs)
- `alembic` round trip (item 9).
- `pytest -q -p no:cacheprovider tests/unit tests/integration` — counts. Then identify pre-existing failures by
  running the same command on a clean baseline (`git stash -u`, run, `git stash pop` — make sure you restore your
  work; note the baseline needs the DB downgraded to 0043 first, then re-upgrade afterwards) and list any test that
  fails with your change but passes on baseline (must be none).
- Full suite `pytest -q -p no:cacheprovider` counts too.
- `ruff check src tests` and `mypy` results (compare to baseline error count if mypy is not clean on baseline).
