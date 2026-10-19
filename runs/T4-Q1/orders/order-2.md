# Work order 2 — review fixes for mindmap_resolve / cheap reads

Good first pass. Fix the following (all in files you already touched); keep everything else.

## 1. Use `Literal` types, not `str`, for enumerated inputs
- `MindmapResolveInput.disposition: Literal["resolved","dropped"] = "resolved"`,
  `resolved_by_party: Literal["owner","model"] = "model"`.
- `MindmapGetInput.include: Literal["open","all"] = "open"`, `depth: Literal["summary","full"] = "summary"`.
Invalid values must be rejected by Pydantic validation (as the other mindmap tools do with `_NodeRole` etc.).
Remove the now-dead manual checks in the tool (`inp.disposition not in RESOLVE_DISPOSITIONS`, the
`include_val`/`depth` fallbacks). Replace the unit tests `test_disposition_invalid_accepted_by_model` and
`test_resolved_by_party_invalid_accepted_by_model` (they are YOUR new tests, so changing them is fine) with tests
asserting `ValidationError` for invalid disposition / party / include / depth.

## 2. `mindmap_resolve`: check + write must be atomic
Currently the live-map and membership checks run in one `tenant_tx` and the update in a second one, so the map
could be archived (or the row changed) in between. Restructure:
1. read-only `tenant_tx`: resolve team, map root (unknown → -32602 path map_key), live check (map_not_live),
   membership + root-node checks (as now) — keeps the error precedence.
2. resolver validation in `system_tx` (as now).
3. ONE write `tenant_tx` that: locks + re-checks the map is live (`SELECT state FROM memory_maps WHERE
   root_memory_id=$1 AND tenant_id=$2 FOR UPDATE`; not live → map_not_live), does the status UPDATE with
   `WHERE memory_id=$1 AND root_memory_id=$2 AND tenant_id=$3 AND node_role <> 'root' RETURNING ...`
   (no row → the same -32602 node_id error; the exception rolls back the tx), inserts the edge, logs the event,
   reads the cursor.
- `set_branch_status` must filter on `tenant_id` explicitly (defence in depth; CONVENTIONS) and return whether a
  row was updated (or the row). Add a service helper for the map lock/live check.
- Move the ad-hoc `SELECT team_id FROM memories WHERE id = $1` out of the tool into the service (e.g. return the
  settled node's `team_id` from `get_membership` / the UPDATE ... RETURNING via a join or a service function
  with `AND tenant_id = $n`). No raw SQL in the tool.

## 3. `mindmap_get` fixes
- `open_loops` must be computed over the WHOLE map, independent of `since`/`include`. Right now it is derived
  from the windowed `members` list (so `since=cursor` returns empty open_loops). Use
  `service.fetch_open_loop_ids` (currently unused). Add `AND m.deleted_at IS NULL AND m.tenant_id = $2` there.
- Remove the dead first `nodes = [...]` list comprehension and the "# Fix:" comment; build nodes once.
- `since=None` must mean "all current members" with NO dependency on the event log (a member with no event
  row must still be returned). Only `since=N` consults events.
- Compute the touched-id set once per request, not twice (members + settled each call it now). E.g. one service
  function returning all window members with their status/summary/party columns, and the tool splits them
  into `nodes` vs `resolved` by status and `include`. Keep it simple.
- Every member query must also have `AND m.deleted_at IS NULL` and the tenant filter, like `fetch_members`.
- `resolved` entries ordered by `added_at` (deterministic).
- Edges: return internal edges (both endpoints are map members, as before) where AT LEAST ONE endpoint is in the
  returned set (`nodes` ∪ `resolved`). Currently both endpoints must be in the returned set, which drops an edge
  from a newly written node to an older node during a `since` read. Without `since` and with `include="all"`
  the result must equal the old behaviour (all internal edges).
- The `(payload->>'target')::uuid` cast must not blow up on a malformed payload: guard with a regex/`CASE` or
  compare as text (e.g. join `mm.memory_id::text = payload->>'target'`).

## 4. Migration
- The index must be `memory_map_events (root_memory_id, id)` (serves `MAX(id)` and `id > N` per map), not
  `(root_memory_id, memory_id)`. Since this migration is unreleased, edit 0044 in place, then
  `alembic downgrade -1 && alembic upgrade head`.
- Run `ruff format` on the migration (and all changed/new files); file must end with a newline.
- Prefix constraint names consistently with the table (`memory_map_membership_..._check`).

## 5. Tests to add (new tests in your new files)
- `since=<cursor>` after writing a node: `open_loops` still lists older open loops (whole-map), and an edge from
  the new node to an older node is in `edges`.
- `include="all"`, no `since`: edges equal the set of all internal edges.
- Resolve on a map archived between check and write is hard to test; at least assert resolve on an archived map
  returns `map_not_live` and changes nothing (exists — keep).

## 6. Verification — required in the report
- `alembic downgrade -1 && alembic upgrade head`.
- `pytest -q -p no:cacheprovider tests/unit tests/integration` — exact pass/fail counts.
- Full suite `pytest -q -p no:cacheprovider`: list failing test ids. Then get the baseline: `git stash -u`,
  `alembic downgrade 0043_backfill_personal_teams`, run the full suite, record failing ids, `git stash pop`,
  `alembic upgrade head`. Report both lists and confirm the "after" failures ⊆ "before" failures.
- `ruff check src tests`, `ruff format --check src tests alembic/versions/0044*`, `mypy` — report output for
  the changed files.
