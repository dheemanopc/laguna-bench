# Work order 2 — finish and tighten the suite (TESTS ONLY; same rules as order 1)

Same hard rules as order 1: new test files only, no edits to `src/`, `alembic/`, conftest,
pyproject, or pre-existing tests. Everything must pass/xfail(strict) on current source,
deterministically, in parallel against a shared DB.

The integration file for memory_list was not finished, and several unit assertions are too
loose to kill mutants. Fix the following.

## A. `tests/integration/test_memory_list_db.py` — make it real, run it, investigate bugs
1. It currently can't run: tests call `_setup_tenant_and_team(pg_pool, suffix="-1")` but the
   parameter is named `tenant_email_suffix`. Fix it, then actually RUN the file and make every
   test either pass or (for genuine, deterministic source bugs) be `xfail(strict=True, reason="BUG: ...")`.
   Do NOT paper over failures by loosening asserts.
2. Confirm `_insert_memory` matches the real `memories` schema (required columns, CHECK
   constraints, content_tsv generation, embedding column dim). If `content_tsv` is a generated
   column / trigger, the keyword tests rely on it — verify.
3. `test_team_id_filter`: the second team belongs to another tenant's setup; make it a second
   team created for the SAME tenant (with assign_role) so the test is meaningful, assert
   `team_id=team1 → {m1}` and `team_id=team2 → {m2}`, and no filter → `{m1, m2}`.
4. `test_include_expired_flag`: use exact set equality for the exclude case (`== {m1, m3}`).
5. `test_content_truncated_to_2000`: use content that varies (e.g. `"".join(str(i % 10) for i in range(5000))`)
   and assert `content == long[:2000]`; also assert `preview == long[:280]` (no keywords).
6. **Pagination — investigate and pin**. Use 5+ memories with distinct explicit created_at.
   Walk all pages with `limit=2` in desc and in asc order, and with `order_by="updated_at"`
   (distinct updated_at order different from created_at). Correct behaviour: concatenated
   pages == full ordered list exactly (no gaps, no dups), last page `next_cursor is None`.
   Find out what really happens on the real DB when you pass `next_cursor` back (asyncpg
   may reject the ISO string for a timestamptz param → exception; or the first row of each
   following page may be skipped because the cursor is the overflow row and the predicate is
   strict). Write:
   - passing tests for what *is* correct (e.g. page 1 contents/order exact; next_cursor
     decodes to the (limit+1)-th row's `[created_at.isoformat(), id]`, i.e. the row that
     is NOT on page 1);
   - strict-xfail tests for the correct full-walk behaviour if broken (separate tests for
     desc, asc, updated_at), each with a precise `reason="BUG: ..."` naming the actual
     failure you observed (exception type/message or which id was skipped).
   - Tie-break: two+ memories sharing the exact same created_at, `limit=1` walk desc; correct
     behaviour = each id exactly once. xfail(strict) only if deterministic.
7. **Invalid cursor via the real tool** (DB-backed or mock, your choice, but via `MemoryListTool.__call__`):
   correct behaviour for each → `JsonRpcError` with `code == -32602`, `message == "invalid cursor"`,
   `data["errors"][0]["path"] == "cursor"`. Parametrize separately:
   - passing: `"not-base64!!!"`, base64 of `b"not json"`, base64 of `[]`, base64 of `["x"]`, base64 of `b"\xff\xfe"` (non-UTF8);
   - check (xfail strict if they don't produce -32602): base64 of `{}`, `5`, `null`, `"str"`,
     and (DB-backed) a well-formed list with a bad id `["2026-01-01T00:00:00+00:00", "not-a-uuid"]`
     and a bad timestamp `["yesterday-ish", "<valid uuid>"]`. Record what actually happens for each.
8. Add DB tests (exact id sets/orders, own tenant only):
   - tags: memories with `[a,b]`, `[a]`, `[b]`, `[a,b,c]`, `[]` → `tags=[a,b]` == {ab, abc};
     `tags=[a]` == {ab, a, abc}; `tags=[]` == all five (empty list treated as no filter);
     `tags=["zzz"]` == empty.
   - since only / until only boundaries (inclusive at exact timestamp, exclusive 1µs off).
   - keywords: contents "Postgres runs fast", "we chose redis", "nothing relevant here",
     "the postgres planner" → `keywords="postgres"` == ids of 1 and 4; `keywords="redis postgres"`
     == 1,2,4 (OR); `keywords="running"` matches "runs" (stemming); `keywords="the a"` → [];
     `keywords="kubernetes"` → []. For keyword results assert `"**Postgres**"` / `"**postgres**"`
     appears in `preview` (exact case as in content) and `content` unchanged; result order still
     follows created_at desc (not relevance) — set created_at explicitly to check.
   - keyword + long content: a 3000-char content whose keyword appears early → preview contains
     `**kw**` and `len(preview) <= 600`; content length 2000.
   - item fields round-trip: for one inserted memory assert every `MemoryListItem` field
     (type, tags, version, is_current, created_at, updated_at, deleted_at, expires_at,
     indexable, embedding_status) equals what was inserted (use version=3, indexable=False,
     embedding_status a valid non-default value, non-null expires_at in the future, etc.).
   - include_deleted + include_history + include_expired all true → exact union.
   - `limit=1` with 1 row → no cursor; with 2 rows → cursor.
   - audit via the real DB: use whatever real audit logger the app uses (look in
     `mem_mcp.audit.logger`) if it writes to an `audit_log`-style table with tenant scoping;
     assert the row's action `memory.list`, result `success`, and details
     `{"result_count", "has_next", "filters_count"}` exact. If that is impractical, skip this
     item (unit-level recording fake covers it) and say so.
9. Speed: share one tenant setup per test or per module where safe (module-scoped async fixtures
   may conflict with the function-scoped `pg_pool`; if so keep per-test setup but batch inserts
   in one transaction). Report the file's runtime.

## B. `tests/unit/test_memory_list_contract.py` — tighten for mutation testing
Replace "x in params" / substring checks with exact ones (edit your own new file freely):
1. For every single-filter test, assert the **exact** params list, e.g.
   `type="decision"` → `params == [tenant, "decision", 26]` and `"(type = $2)" in query`;
   `tags` → `[tenant, ["python","async"], 26]` and `"(tags @> $2)"`; `since`+`until` →
   `[tenant, since, until, 26]`, `"(created_at >= $2)"`, `"(created_at <= $3)"`; `team_id` → `"(team_id = $2)"`;
   `indexable` True and False → `"(indexable = $2)"` and exact param (`is True` / `is False`);
   `parent_id` → `"(parent_id = $2)"`; keywords → `[tenant, "postgres async", 26]` with
   `"content_tsv @@ to_tsquery('english'"` and `$2` referenced; LIMIT placeholder exact (`LIMIT $3`).
2. One "all filters" test: type, tags, since, until, team_id, indexable, parent_id, keywords,
   cursor, limit=7 → exact params list in exact order
   `[tenant, type, tags, since, until, team_id, indexable, parent_id, keywords, iso, id_str, 8]`
   and exact placeholders: `(type = $2)`, `(tags @> $3)`, `(created_at >= $4)`, `(created_at <= $5)`,
   `(team_id = $6)`, `(indexable = $7)`, `(parent_id = $8)`, `$9` in the tsquery,
   `((created_at, id) < ($10, $11::uuid))`, `LIMIT $12`.
3. Default query: assert exact `WHERE` string
   `"(tenant_id = $1) AND (deleted_at IS NULL) AND ((expires_at IS NULL OR expires_at > NOW())) AND (is_current = true)"`
   is in the query; `"LEFT(content, 2000) AS content"` and `"LEFT(content, 280) AS preview"`
   present, `ts_headline` absent. With all include_* True and no filters: WHERE is exactly
   `"(tenant_id = $1)"` (check `"WHERE (tenant_id = $1)\n"` or equivalent robust exact check)
   and params `[tenant, 26]`.
4. keywords preview select: assert exact substring
   `"LEFT(COALESCE(ts_headline('english', LEFT(content, 8000), "` and
   `"'StartSel=**, StopSel=**, MaxFragments=2, MaxWords=30, MinWords=8, FragmentDelimiter=\" … \"'), LEFT(content, 280)), 600) AS preview"`
   (build the expected strings from the hybrid_query constants AND hardcoded literals — at least
   one assertion must hardcode the literal numbers 8000/280/600 so constant mutants die).
5. ORDER BY: all four combos exact: `"ORDER BY created_at DESC, id"`, `"ORDER BY created_at ASC, id"`,
   `"ORDER BY updated_at DESC, id"`, `"ORDER BY updated_at ASC, id"`.
6. Cursor predicate: exact `"((created_at, id) < ($2, $3::uuid))"` desc, `"> "` asc,
   `"((updated_at, id) < ($2, $3::uuid))"`, `"((updated_at, id) > ($2, $3::uuid))"`; exact params
   `[tenant, iso, id_str, 26]`.
7. next_cursor: with `order_by="updated_at"` and rows whose created_at ≠ updated_at, cursor
   decodes to `[rows[limit]["updated_at"].isoformat(), str(rows[limit]["id"])]`; with created_at
   default ordering likewise (use distinct created/updated values so mutants swapping columns die).
   Also assert the returned result ids == first `limit` row ids in order (overflow row dropped).
   Also exact: `next_cursor == _encode_cursor(rows[limit][col], rows[limit]["id"])`.
8. Audit (recording fake, not MagicMock-ish loose checks): exactly one call; positional conn is
   the fake conn; kwargs exactly
   `{"action": "memory.list", "result": "success", "tenant_id": ctx.tenant_id, "identity_id": ctx.identity_id,
   "client_id": ctx.client_id, "request_id": ctx.request_id, "details": {...}}`. Scenarios:
   default with 5 rows → `{"result_count": 5, "has_next": False, "filters_count": 3}`;
   limit=2 with 3 rows → `{"result_count": 2, "has_next": True, "filters_count": 3}`;
   all include_* True no filters → filters_count 0; all-filters + cursor scenario → filters_count
   3 + 8 + 1 = 12 (verify the real number and assert it exactly).
9. Errors: deps None → `code == -32603` and `message == "tool deps not wired"` (exact equality);
   invalid cursor → also assert `data == {"errors": [{"path": "cursor", "message": <str>}]}` with
   message starting `"Invalid cursor format: "`, and that `conn.fetch` was NOT awaited and audit NOT called.
   deps-None check happens before cursor parsing (deps None + bad cursor → -32603).
10. Output mapping: assert each `MemoryListItem` field equals the row value for a fully
    populated row (non-default version, is_current False, deleted_at/expires_at set, indexable False).
11. `description == TOOL_DESCRIPTIONS["memory_list"]`, and the description contains
    `"ALL the listed tags"` (contract text).
12. `_encode_cursor`: exact output string equality against a hand-computed value for a fixed
    datetime and fixed UUID (hardcode the expected base64 string, computed once). `_decode_cursor`
    error message exactly starts with `"Invalid cursor format: "`.
13. Keep the existing `_decode_cursor({})` xfail but also add a tool-level version (part A.7).

## C. Notices — tighten
1. Unit: `queue` — assert the exact JSON string `args[4]` for a fixed payload, e.g.
   `{"fire_at": datetime(2026,6,15,10,30,tzinfo=UTC), "d": date(2026,6,15), "id": UUID("12345678-1234-5678-1234-567812345678"), "n": 1}`
   → `'{"fire_at": "2026-06-15T10:30:00+00:00", "d": "2026-06-15", "id": "12345678-1234-5678-1234-567812345678", "n": 1}'`.
   Nested (list/dict inside payload) datetimes too. Assert the `plugin_notice_queued` INFO log
   record with `record.plugin_id` and `record.kind` exact. Assert queue makes exactly 1 execute
   and passes the pool to `system_tx` (capture the arg).
2. Unit: `deliver_pending` — assert `len(result) == 3` in the order test; assert fetch query
   contains `"delivered_at IS NULL"`, `"expires_at > now()"`, `"ORDER BY created_at ASC"`,
   `"LIMIT $2"`, `"FOR UPDATE SKIP LOCKED"`, `"SET delivered_at = now()"`, `"tenant_id = $1"`,
   and exact positional args `(tenant_id, 20)`. Missing-key rendering through deliver_pending
   (`"Hi {name}{missing}!"` with `{"name": "A"}` → `"Hi A!"`). Payload str `"null"`? (skip if it
   would crash and is not contract — note it).
3. Unit `_render`: `"{a}{b}"` adjacent; `"{{a}}"` with `{"a":"x"}` → `"{x}"`; missing key in the
   middle; warning record `levelno == logging.WARNING`; exactly one warning per missing occurrence.
4. Integration `test_plugin_notices_db.py`:
   - TTL: assert **exact** `expires_at - created_at == timedelta(seconds=ttl)` (same `now()` in
     one statement) for default (86400, call without ttl kwarg) and custom (3600) and small (1).
   - Keep the two jsonb-double-encoding xfails only if they really fail for that reason; ALSO add
     a PASSING test that the datetime/date/UUID payload survives `queue → deliver_pending`:
     delivered `payload == {"fire_at": dt.isoformat(), "date_field": d.isoformat(), "item_id": str(u)}`
     and the template `"Due {fire_at} ({item_id})"` renders exactly. (This is the
     "notices crashed on datetime payloads" regression.)
   - Oldest-first: insert rows in **reverse** chronological order (newest inserted first) with
     explicit created_at, then deliver → must come back oldest-first. If that fails, pin with
     strict xfail ONLY if it fails 20/20 runs; report what you observe either way.
   - limit: 5 notices with explicit created_at; `limit=3` → exactly the 3 oldest ids in order;
     next call → remaining 2 in order; third call → []. Default limit: 21 pending → first call
     returns exactly 20 (the 20 oldest), second returns the 21st.
   - at-most-once: assert the second call's ids are disjoint and that `delivered_at` is set for
     exactly the delivered ids.
   - already-delivered row (insert with `delivered_at = now()`) and expired row never returned.
   - to_dict on a real notice: exact equality with
     `{"id": str(row_id), "plugin_id": ..., "kind": ..., "text": ..., "payload": ..., "created_at": created_at.isoformat()}`
     where row_id/created_at are read back from the table.
   - missing placeholder through the real pipeline renders as empty string.

## Verification (report exact output)
1. `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py tests/unit/test_search_preview_lenient.py tests/unit/test_memory_list_contract.py tests/unit/test_notice_pipeline_contract.py tests/integration/test_memory_list_db.py tests/integration/test_plugin_notices_db.py -rxX`
   (show the xfail list with reasons).
2. Run the 4 new files 5× in a row; and 2 concurrent copies (`(pytest A & pytest B; wait)`); report.
3. `ruff check` on the new files; `ruff format --check` on them (format them if needed).
4. Full `pytest -q` counts; confirm failures only in pre-existing files.
5. `git status --porcelain` — only the 4 new test files.
Report: what changed, every bug (one line + test name + observed failure), suspects that turned
out not to be bugs (with evidence), runtimes.
