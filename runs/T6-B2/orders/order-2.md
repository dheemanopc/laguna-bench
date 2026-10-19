# Order 2 — Fix-ups to the four new test files (still TESTS ONLY)

Same hard rules as order 1: edit only your four new files; no changes to `src/`, `alembic/`, conftest, existing tests.

## A. MUST FIX — shared-DB schema mutation
`tests/integration/test_memory_list_behaviour.py::_install_tsvector_to_array` runs `CREATE OR REPLACE FUNCTION
tsvector_to_array(...)` in the shared database. **Remove it entirely and all calls to it.** `tsvector_to_array(tsvector)`
is a built-in PostgreSQL function (pg_catalog, since 9.6) — it is not missing. Creating a public-schema function mutates
the shared DB and concurrent `CREATE OR REPLACE` from parallel mutation workers can fail with "tuple concurrently
updated". After removing it, re-run the keyword tests and confirm they pass using the built-in. Remove the docstring
claim about it too. (If something actually fails without it, report the exact error instead of re-adding it.)

## B. MUST FIX — tests that pin buggy behaviour
In `tests/unit/test_memory_list_models_cursor.py`, `test_decode_json_integer_raises_type_error_not_caught`,
`test_decode_json_dict_raises_key_error_not_caught`, `test_decode_json_bool` assert the *buggy* behaviour. Replace them
with correct-behaviour tests marked `@pytest.mark.xfail(strict=True, reason="BUG: …")`:
- calling `MemoryListTool` with cursor = urlsafe-b64 of `42`, of `{"a": 1}`, of `true` → must raise `JsonRpcError`
  with code `-32602` and message `"invalid cursor"` (one parametrized xfail test, or three).
- Also add (xfail if it fails) a real-DB test: a cursor that decodes cleanly but carries a malformed timestamp
  (`["not-a-date", "<valid uuid>"]`) or malformed uuid (`["2026-01-01T00:00:00+00:00", "nope"]`) → `-32602`.
Also delete `test_plugin_id_is_uuid_not_string` in `tests/unit/test_notice_render_and_serialize.py` and use a `str`
plugin_id everywhere there (`plugin_id` is typed `str`); `test_to_dict_serializable_with_default_str` should then use
plain `json.dumps` with no `default`.

## C. Pagination bugs — separate, narrow xfails
Keep the existing cursor-crash xfails, but make sure each distinct bug has its own narrow strict xfail:
1. (existing) cursor ISO string vs timestamptz → second page crashes. Keep one walk test for each
   order_by×order combination (parametrize, 4 cases), each asserting the exact concatenated ordered id list.
2. NEW: `next_cursor` should point at the last row **returned** (keyset with strict `<`/`>`): insert 3 rows with distinct
   created_at, call `limit=2`, decode `next_cursor` with `_decode_cursor` and assert it equals
   `(results[-1].created_at.isoformat(), str(results[-1].id))`. Currently it encodes the 3rd (un-returned) row, so the
   next page would skip it → strict xfail `reason="BUG: next_cursor encodes the (limit+1)th row; strict keyset predicate skips it"`.
   Verify the actual decoded value equals the 3rd row (mention in report).
3. NEW: tie-breaking: desc order sorts `created_at DESC, id ASC` but the cursor compares `(created_at,id) < (…)`
   (which implies id DESC). Write the correct-behaviour test: 4 rows sharing one created_at, `order="desc"`, `limit=1`,
   walk all pages → exactly the 4 ids, each once. strict xfail with a reason naming the tie-order mismatch.
4. Also add a passing test pinning first-page tie order is deterministic? No — skip; don't pin it.

## D. Strengthen weak assertions (mutation testing kills nothing that isn't asserted exactly)
Replace `len(...) == N` / `startswith` / `"**" in` checks with **exact** id sets or exact ordered id lists everywhere.
Specifically:
- Tenant scoping: exact id sets for A and B.
- include_deleted / include_expired / include_history: exact id sets both default and with flag. Expired test must have
  three rows: `expires_at=NULL`, `expires_at=now+1h` (future → included by default), `expires_at=now-1h` (excluded).
  Use ±1 hour, not ±1 s. Add one test combining all three include_* flags = True → every row.
- Tags: add a row with a superset of tags (`["a","b","c"]`) → included; `tags=[]` → no filter (all rows).
- since/until: exact id sets; add combined `since`+`until` window.
- team_id: also assert the other team; indexable: exact sets.
- Keywords: OR test exact id set; preview must contain the exact marked token, e.g. `"**fox**" in preview`;
  `len(preview) <= PREVIEW_MAX_CHARS`; add a keywords test on a long content (>PREVIEW_FALLBACK_CHARS) where the match is
  near the END so the preview is NOT the head of content (assert the marked token in preview and
  `preview != content[:PREVIEW_FALLBACK_CHARS]`). Keyword + another filter (e.g. type) combined → exact set.
- No-keywords preview: assert `preview == content[:PREVIEW_FALLBACK_CHARS]` using the imported constant (not literal 280),
  and for short content `preview == content`.
- Content truncation: assert `content == long_content[:2000]` using a non-uniform string (e.g. `"".join(str(i%10) …)`),
  plus a 2000-char and 2001-char case.
- Ordering: rows whose created_at order differs from their updated_at order (e.g. created ascending A,B,C but updated
  C,A,B). Assert the exact ordered id list for all 4 order_by×order combos.
- Limit: N == limit → `next_cursor is None` and all N returned; N == limit+1 → exactly `limit` returned, the returned
  ids are exactly the first `limit` of the expected order, and `next_cursor is not None`; `limit=1` case.
- Audit (DB-backed): add cases with exact `details`: e.g. `type + tags + keywords + team_id + indexable + parent_id +
  since + until` and all include_* = True → compute exact `filters_count`; a has_next=True case with exact
  `result_count`. Also keep the mock-based ones.
- Output fields: insert a row with non-default values (`version=3`, `is_current=False` with include_history,
  `deleted_at` set with include_deleted, `expires_at` future, `indexable=False`, `embedding_status` some other valid value
  per schema, explicit created_at/updated_at) and assert every field equals the inserted value exactly.

## E. Notices
- TTL: assert exactly `row["expires_at"] - row["created_at"] == timedelta(seconds=86400)` (default) and
  `== timedelta(seconds=60)` (custom) — both come from `now()` in one statement. Drop the wall-clock windows. Add
  `ttl_seconds=0` → expires_at == created_at, and that such a notice is never delivered.
- Default `limit`: call `deliver_pending(conn, tenant)` **without** `limit` with 21 pending → exactly 20 returned (the
  20 oldest), then 1. Use explicit created_at values.
- Oldest-first ORDER: the order of the returned list is part of the contract ("Returns up to `limit` rendered
  notices, oldest first"). Do not sort before comparing. Insert rows in non-chronological physical order (and with
  more rows, e.g. 6 inserted in shuffled order) and assert the returned list order equals created_at ascending.
  Run it ~20 times (`pytest --count` if pytest-repeat exists, else a loop in the shell) to see whether current code
  returns them in order deterministically:
  - if it always returns oldest-first → plain passing test asserting exact order;
  - if it deterministically returns a different order → strict xfail `reason="BUG: UPDATE … RETURNING does not preserve
    the subquery's ORDER BY; results not oldest-first"`, and keep the separate set-based tests passing;
  - if it is nondeterministic → do not xfail strict; report it and use `xfail(strict=False)` with the BUG reason.
  Same for the `limit=2` test: the *selection* (which 2) as a passing set test, order as part of the order test.
- At-most-once: also assert `delivered_at IS NOT NULL` for exactly the delivered ids and `IS NULL` for undelivered ones
  (limit case). Already-delivered rows inserted with `delivered_at` set are never returned.
- Tenant isolation: after delivering tenant A, tenant B's rows still have `delivered_at IS NULL` (check in DB), then B
  delivers its own exact set.
- Missing-key warning: assert via caplog `record.key` and `record.template == template[:120]` with a >120 char template
  (and `!= template`).
- Queue round-trip: queue a payload containing tz-aware datetime, naive datetime, date, UUID, nested list/dict,
  then `deliver_pending` → exact `payload` dict and exact rendered `text` (e.g. template `"due {fire_at} id {item}"`).
- `to_dict()` from a delivered notice: exact full dict equality
  (`{"id": str(id), "plugin_id": ..., "kind": ..., "text": ..., "payload": {...}, "created_at": created_at.isoformat()}`).
- Queue log: keep the mock-based log check, or use caplog on logger `mem_mcp.plugins.clients.notices` with exact
  `record.getMessage() == "plugin_notice_queued"`, `record.plugin_id`, `record.kind`.

## F. Hygiene
- Keep everything deterministic, fast, and isolated (UUID-suffixed tenants; never assume empty tables).
- `ruff check` clean on the four files; `mypy` not required but avoid obviously wrong annotations.

## Report
- `pytest -q -p no:cacheprovider <four files>` ×3 (exact summary lines), wall time; with xdist `-n 4` if available.
- `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_search_preview_lenient.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <four files>`.
- Result of the oldest-first repetition experiment (what order came back).
- Final list of every xfail and the concrete observed failure for each.
- `git status --short` (only the four new files).
