# Work order 5 — fix pagination xfails, add remaining memory_list DB tests (TESTS ONLY)

Good find on the DataError. Same rules as before. Paste raw pytest output in the report.

## Step 1 — fix `tests/integration/test_memory_list_pagination_db.py`
1. Every `xfail(..., raises=Exception, ...)` is too broad: it would also "xfail" on an
   AssertionError from a wrong expectation. Change to
   `raises=asyncpg.exceptions.DataError` (import asyncpg) everywhere, including
   `test_basic_pagination_walk` in `test_memory_list_db.py` if it uses a broad `raises`.
2. `test_full_walk_updated_at` has a WRONG expected list. With updated_at hours m0=3, m1=0,
   m2=4, m3=1, m4=2, updated_at DESC is `[m2, m0, m4, m3, m1]`. Fix the assertion and comment.
3. Add a PASSING test `test_first_page_updated_at_cursor`: same data as (2), `limit=2`,
   `order_by="updated_at"` → results `[m2, m0]`, and `_decode_cursor(next_cursor) ==
   ((base + timedelta(hours=2)).isoformat(), str(m4))` (cursor uses updated_at of the overflow row).
4. Add a PASSING test `test_first_page_asc_cursor`: m0..m4 by created_at, `order="asc", limit=2`
   → `[m0, m1]`, cursor decodes to `(created_at of m2 .isoformat(), str(m2))`.
5. Make the xfail reasons mention both problems:
   `"BUG: cursor timestamp is bound as str to a timestamptz param (asyncpg DataError); also next_cursor is the overflow row + strict keyset predicate, which would skip a row per page"`.

## Step 2 — invalid cursors through the tool on the real DB
New tests in the pagination file. Expected for every case: `pytest.raises(JsonRpcError)` with
`.code == -32602`, `.message == "invalid cursor"`, `.data["errors"][0]["path"] == "cursor"`.
Build cursors with `base64.urlsafe_b64encode(<bytes>).decode()`.
Parametrize with ids:
- `garbage`: `"not-base64!!!"` (raw string, not encoded)
- `not_json`: `b"not json"`
- `empty_list`: `b"[]"`
- `one_elem`: `b'["x"]'`
- `non_utf8`: `b"\xff\xfe"`
- `dict`: `b"{}"`
- `int`: `b"5"`
- `null`: `b"null"`
- `string`: `b'"s"'`
- `bad_uuid`: `json.dumps(["2026-01-01T00:00:00+00:00", "not-a-uuid"]).encode()`
- `bad_ts`: `json.dumps(["yesterday", "00000000-0000-0000-0000-000000000001"]).encode()`
Insert at least one memory first so the query actually executes. Run, and for each case that does
NOT produce -32602, wrap its `pytest.param` with
`marks=pytest.mark.xfail(strict=True, raises=<exact exception class observed>, reason="BUG: ...")`.
Paste the observed exception class per failing case.

## Step 3 — more DB tests in `tests/integration/test_memory_list_db.py`
(exact id lists/sets; own tenant; try/finally cleanup)
1. `test_tags_edge_cases` — tags ab=[a,b], a=[a], b=[b], abc=[a,b,c], none=[] where
   `a,b,c` are `f"t-{uuid4().hex[:6]}"`. Assert `tags=[a,b]` → {ab, abc}; `tags=[a]` →
   {ab, a, abc}; `tags=[]` → {ab, a, b, abc, none}; `tags=["zzz-"+uuid]` → set().
2. `test_since_only_until_only` — memories at T-1s, T, T+1s (T = datetime(2026,3,1,12,tzinfo=UTC)).
   `since=T` → {T, T+1s}; `until=T` → {T-1s, T}; `since=T+timedelta(microseconds=1)` → {T+1s};
   `until=T-timedelta(microseconds=1)` → {T-1s}.
3. `test_keywords_filter_and_preview` — contents with created_at c1<c2<c3<c4:
   1 "Postgres runs fast", 2 "we chose redis", 3 "nothing relevant here", 4 "the postgres planner".
   - `keywords="postgres"` → ids `[m4, m1]` exactly (created_at desc);
   - `keywords="redis postgres"` → `[m4, m2, m1]`;
   - `keywords="running"` → `[m1]`;
   - `keywords="the a"` → `[]`; `keywords="kubernetes"` → `[]`;
   - with `keywords="postgres"`: `"**Postgres**" in preview(m1)`, `"**postgres**" in preview(m4)`,
     and `content` equals the original content for both;
   - with no keywords: each `preview == content` (short contents) — exact.
   First check how `content_tsv` gets populated (generated column vs trigger vs app code).
   If your direct `_insert_memory` doesn't populate it, populate it in the helper the same way the
   app does. Don't drop the tests.
4. `test_keywords_long_content_preview` — content = "postgres " + 3000 chars of other varied
   words (e.g. `" ".join(f"word{i}" for i in range(600))`), `keywords="postgres"` →
   `"**postgres**" in preview`, `len(preview) <= 600`, `content == original[:2000]`.
   Also with no keywords: `preview == original[:280]` exactly.
5. `test_item_fields_round_trip` — one memory: type="fact", tags=[x, y], version=3,
   is_current=True, indexable=False, embedding_status = a valid non-"ok" value (check the CHECK
   constraint / enum), expires_at = `datetime(2099,1,1,tzinfo=UTC)`, created_at/updated_at fixed and
   different. Assert every `MemoryListItem` field == inserted values (id, content, preview, type, tags,
   version, is_current, created_at, updated_at, deleted_at None, expires_at, indexable, embedding_status).
   Second memory with `deleted_at = datetime(2026,2,2,tzinfo=UTC)` listed with `include_deleted=True`
   → its `deleted_at` equals that value.
6. `test_include_flags_combined` — normal N, deleted D, expired E (expires_at in the past), non-current H
   (is_current=False). Default → {N}; include_deleted → {N, D}; include_expired → {N, E};
   include_history → {N, H}; all three → {N, D, E, H}.
7. `test_limit_one_edge` — 1 memory, `limit=1` → 1 result, `next_cursor is None`; add a 2nd (newer) →
   `limit=1` returns only the newer, `next_cursor is not None`.

## Step 4 — verification (paste raw)
```
pytest -p no:cacheprovider tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py -rxXs -q 2>&1 | tail -40
```
Then run it 3 times more and paste the count lines, and run two copies concurrently:
`(pytest -q -p no:cacheprovider tests/integration/ -k "memory_list" & pytest -q -p no:cacheprovider tests/integration/ -k "memory_list"; wait)` and paste.
Run `ruff check tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py`
and `ruff format --check` on the same — if a permission error occurs, paste the exact error text.
