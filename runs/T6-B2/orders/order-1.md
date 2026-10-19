# Order 1 — Behaviour-focused test suite for `memory_list` and plugin notices (TESTS ONLY)

## Hard rules
- **Do not modify anything** under `src/`, `alembic/`, `pyproject.toml`, any `conftest.py`, or any existing test file.
  Only ADD new test files. Suggested:
  - `tests/integration/test_memory_list_behaviour.py` (DB-backed, real Postgres)
  - `tests/unit/test_memory_list_models_cursor.py` (pure unit: input model, cursor helpers, deps-missing error, audit kwargs)
  - `tests/integration/test_plugin_notices_behaviour.py` (DB-backed queue + deliver_pending)
  - `tests/unit/test_notice_render_and_serialize.py` (pure unit: `_render`, `_json_default`, `RenderedNotice.to_dict`)
- All new tests must PASS on the current, unmodified source (`ruff check` clean too).
- If you find real bugs: do NOT fix them. Write the test asserting the *correct* behaviour and mark it
  `@pytest.mark.xfail(strict=True, reason="BUG: <one line>")`. Each xfail must fail **deterministically** on current code
  (run it repeatedly to be sure — a strict xfail that sometimes passes is a flaky test, which is unacceptable).
  Keep xfail tests narrow (one bug per test) and make sure the *non-buggy* behaviour around it is covered by
  separate passing tests so that coverage is not lost.

## Modules under test (scored by mutation testing, mutmut, restricted to these three files)
1. `src/mem_mcp/mcp/tools/list.py` — `MemoryListTool`, `MemoryListInput/Item/Output`, `_encode_cursor`, `_decode_cursor`.
   Behavioural contract: `TOOL_DESCRIPTIONS["memory_list"]` in `src/mem_mcp/mcp/tool_descriptions.py`.
2. `src/mem_mcp/plugins/clients/notices.py` — `NoticeClientImpl.queue`, `_json_default`.
3. `src/mem_mcp/plugins/notice_delivery.py` — `deliver_pending`, `_render`, `RenderedNotice.to_dict`.

Because scoring is mutation testing, every test must assert **exact** observable values: exact ID sets / exact ordered ID
lists, exact strings, exact error codes/messages/data, exact counts, exact timedelta, exact audit kwargs. Mutants change
string literals (which breaks SQL fragments — so real-DB tests kill those), numeric constants (2000 → 2001, +1 → +2),
comparison operators, `"<"`/`">"`, `asc`/`desc`, default arguments (`limit=20`, `ttl_seconds=86400`, `limit=25`,
`le=100`, `max_length=512`, `min_length=1`), dict keys in audit details / `to_dict`, log message names and `extra` keys.
Design a test that would fail for each such change. Existing tests (`tests/unit/test_tools_list.py`,
`tests/unit/test_search_preview_lenient.py`, `tests/unit/test_notice_delivery.py`,
`tests/unit/test_notice_client_serialization.py`) are mostly mock-based; read them, and don't merely duplicate them.

## Isolation / speed requirements (mutation runs execute the suite hundreds of times, in parallel, on ONE shared DB)
- Use the `pg_pool` fixture (`tests/conftest.py`). Create your own tenant/team/identity/oauth_client per test (or per
  module if the fixture scopes allow) with UUID-suffixed emails/names; follow `_setup`/`_cleanup`/`_ctx`/`_build_deps`
  in `tests/integration/test_mindmap_e2e.py`. A second tenant is needed for tenant-isolation tests. Clean up afterwards.
- Never assume empty tables; always filter/assert relative to your own tenant's rows.
- No sleeps or wall-clock races. For deterministic ordering/expiry, **insert `memories` and `plugin_notices` rows
  directly with SQL with explicit `created_at`/`updated_at`/`expires_at`/`deleted_at`/`delivered_at`/`is_current`/
  `version`/`indexable`/`parent_id`/`team_id`/`tags`/`type`** (inspect the `memories` schema in `alembic/versions/` for
  required columns, generated columns like `content_tsv`, triggers, and FK constraints; use a connection that can write
  them, e.g. the same way the e2e test's `_setup` does). Use `MemoryWriteTool` with a stub embedder only if direct
  insert is impractical. Use distinct, well-separated timestamps (e.g. a base time + N minutes) and also add one
  deliberate tie case where needed.
- Whole new suite should run in a few seconds.

## What to cover — `memory_list` (real DB unless noted)
- Tenant scoping: tenant B's memories never appear for tenant A (exact ID set).
- Tags: ALL requested tags required (memory with only a subset excluded); single tag; tags=[] / None means no filter.
- `type`, `since` (inclusive, `>=` — test a row exactly at the boundary), `until` (inclusive `<=`, boundary row),
  `team_id` (two teams), `indexable` True and False, `parent_id`.
- `include_deleted`, `include_expired` (expires_at in past vs future vs NULL), `include_history` (is_current=false rows)
  — default excludes, flag includes; exact ID sets.
- `keywords`: OR semantics over words, stemming (e.g. "deploying" matches "deployed"), non-matching rows excluded,
  all-stopword input (e.g. "the and of") returns nothing; `preview` contains `**<match>**` markers when keywords given;
  without keywords `preview == content[:PREVIEW_FALLBACK_CHARS]` exactly (import the constant from
  `mem_mcp.memory.hybrid_query`); preview length bounds with keywords (`<= PREVIEW_MAX_CHARS`).
- `content` truncation: a 2500-char body returns exactly `content[:2000]`; a 2000-char body is returned unchanged.
- `order_by` created_at vs updated_at (make the two orders differ) × `order` asc/desc — exact ordered ID lists.
- `limit`: exact number returned; `next_cursor is None` when rows == limit exactly; not None when rows > limit.
- Pagination: walk all pages with `next_cursor` for each order/order_by combination and assert the concatenation
  equals the full expected ordered list with no duplicates and no omissions. Also check that the cursor decodes
  (`_decode_cursor`) to the expected `(iso, id)` of the row the implementation uses.
- Invalid cursor (`"!!!not-base64"`, base64 of non-JSON, base64 of `[]`/`["x"]`) → `JsonRpcError` with code `-32602`,
  message `"invalid cursor"`, and `data["errors"][0]["path"] == "cursor"` (check the exact attribute names on
  `JsonRpcError` in `src/mem_mcp/mcp/errors.py`).
- `ctx.deps is None` → `JsonRpcError(-32603, "tool deps not wired")` (unit).
- Audit: use a recording audit logger (subclass/replace `NoopAuditLogger`) and assert the exact kwargs:
  `action="memory.list"`, `result="success"`, tenant/identity/client/request ids, and exact `details`
  (`result_count`, `has_next`, `filters_count`) for a couple of filter combinations (compute expected
  `filters_count` from the code: it counts every WHERE clause other than tenant, including the default
  deleted/expired/history clauses).
- Output: `request_id` echoed; each item's fields (`version`, `is_current`, `deleted_at`, `expires_at`, `indexable`,
  `embedding_status`, `tags`, `type`) equal what was inserted.
- Input model (unit): defaults; `extra="forbid"`; `keywords` "" rejected, 512 chars ok, 513 rejected; `limit` 0/101
  rejected, 1/100 ok; invalid `type`/`order`/`order_by` rejected; each valid `MemoryType` accepted.
- `_encode_cursor(None, id)` raises `ValueError`; encode/decode round-trip exact; decode errors are `ValueError`
  with message starting `"Invalid cursor format"`.

## What to cover — notices (real DB for queue/deliver)
- `queue` persists exactly one row with the given tenant_id, plugin_id, kind, template, payload; default TTL gives
  `expires_at - created_at == timedelta(seconds=86400)` exactly (both are `now()` in one statement); custom ttl likewise.
- Payloads with `datetime` (tz-aware and naive), `date`, `UUID`, nested dicts/lists, and other objects → stored JSON
  equals the exact expected values (isoformat strings, `str(uuid)`).
- Log record `plugin_notice_queued` with `plugin_id`/`kind` extras (caplog).
- `deliver_pending`: oldest-first order (rows inserted with explicit created_at, inserted in NON-chronological order);
  `limit` honoured; default limit is 20 (queue 21 → 20 returned, then 1); at-most-once (second call returns []
  and `delivered_at` is set in DB); expired rows (expires_at in the past) never delivered; already-delivered rows never
  delivered; other tenant's notices untouched (still undelivered afterwards); empty → `[]`.
- Rendered `text` from template + payload, including missing keys → `""` with a `notice_template_missing_key` warning
  whose record has `key` and `template` (truncated to 120 chars — test with a >120-char template) attributes;
  payload returned as a dict; payload with datetime round-trips via queue → deliver → text.
- `RenderedNotice.to_dict()` exact dict (id as str, created_at isoformat, all six keys, nothing else).
- `_render` edge cases: non-identifier braces left untouched, `{0}`, repeated placeholders, value `None` → `"None"`.

## Suspected bugs to investigate (verify empirically; only xfail what really fails)
1. Pagination: `next_cursor` is encoded from the (limit+1)-th row (`rows[inp.limit]`) but the keyset predicate is
   strict (`<`/`>`), so the first row of the next page may be skipped.
2. The cursor's timestamp is passed to Postgres as an ISO *string*; asyncpg may reject a `str` for a timestamptz
   comparison, so any request with a cursor may crash (non -32602 error). Check what actually happens.
3. Desc order sorts `created_at DESC, id` (id ascending) while the cursor compares the row tuple with `<` — rows with
   equal created_at may be skipped/duplicated across pages.
4. `_decode_cursor` only catches JSONDecodeError/IndexError/ValueError: a base64 JSON *object* (`{}` → KeyError) or
   scalar (`5` → TypeError) cursor, or a cursor with a malformed timestamp/UUID, may escape as a non -32602 error.
5. `deliver_pending` uses `UPDATE … RETURNING`; RETURNING order isn't guaranteed to follow the subquery's ORDER BY,
   so results may not be oldest-first when physical insert order differs from created_at order.
6. The tool description says `team_id` accepts a UUID **or team name**, and `"*"` for cross-team; the input model only
   accepts UUID.
For each: write the correct-behaviour test; if it fails deterministically on current code mark it strict xfail with
`reason="BUG: …"`; if it passes, keep it as a normal passing test.

## Verification to report
- `pytest -q -p no:cacheprovider <your new files>` — exact summary line, run it **3 times** to show stability;
  also run with `-p xdist -n 4` if pytest-xdist is installed.
- `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_search_preview_lenient.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <your new files>`
- `ruff check tests` on your new files; wall time of the new suite.
- `git status` must show only new test files.
- In your report, list every xfail with its bug and the concrete failure observed (exception/actual value).
