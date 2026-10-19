# Order 1 — Mutation-killing test suite for `memory_list` and plugin notices (TESTS ONLY)

## Hard rules
- **Do not modify anything under `src/`, `alembic/`, existing tests, any `conftest.py`, or `pyproject.toml`.** Add NEW test files only.
- New files:
  - `tests/integration/test_memory_list_behaviour.py` (DB-backed, exercises `MemoryListTool` end to end)
  - `tests/unit/test_memory_list_models_cursor.py` (pure: input/output models, `_encode_cursor`/`_decode_cursor`, invalid cursor → error before DB)
  - `tests/integration/test_plugin_notices_behaviour.py` (DB-backed: `NoticeClientImpl.queue` + `deliver_pending`)
  - `tests/unit/test_notice_render_and_dict.py` (pure: `_render`, `_json_default`, `RenderedNotice.to_dict`)
- Tests will be run by **mutmut** against `src/mem_mcp/mcp/tools/list.py`, `src/mem_mcp/plugins/clients/notices.py`, `src/mem_mcp/plugins/notice_delivery.py`. Goal: kill as many mutants as possible. Assert EXACT values: exact id sets/ordered id lists, exact strings, exact error codes/messages/data, exact audit kwargs. Never just "doesn't crash".
- Tests run many times in parallel against ONE shared DB: create your own tenant/team/identity/oauth_client per test (UUID-suffixed emails/ids), never assume empty tables, always filter assertions by your own tenant, clean up in `finally`. No wall-clock races; when ordering by time matters, set `created_at`/`updated_at`/`expires_at` explicitly via SQL `UPDATE` (as superuser/maintenance pool or `system_tx`) rather than sleeping. Keep the whole new suite fast (a few seconds).
- No network. Use a stub embedder (see `tests/integration/test_mindmap_e2e.py` `_build_deps`, `_setup`, `_cleanup`, `_ctx` — copy that pattern: tenant + team + primary identity with `default_team_id` + `oauth_clients` row for the ctx `client_id`). You may create memories with `MemoryWriteTool` or by direct INSERT — direct INSERT (with explicit columns: content, type, tags, created_at, updated_at, deleted_at, expires_at, is_current, version, indexable, parent_id, team_id, etc.) is fine and probably simpler/faster for precise control. Check the `memories` schema/migrations for required columns and that `content_tsv` is populated (generated column or trigger?).
- Read `CONVENTIONS.md`, `tests/conftest.py`, `tests/integration/conftest.py`, and existing `tests/unit/test_tools_list.py`, `tests/unit/test_notice_delivery.py`, `tests/unit/test_notice_client_serialization.py` first so you don't just duplicate them.

## Part A — `memory_list` (`src/mem_mcp/mcp/tools/list.py`)
Behavioural contract = `TOOL_DESCRIPTIONS["memory_list"]` in `src/mem_mcp/mcp/tool_descriptions.py`. Cover, each with exact expected id sets/lists:
1. **Tenant scoping**: two tenants each with memories; listing as tenant A returns only A's.
2. **Tags ALL semantics**: memories with tags `[a]`, `[b]`, `[a,b]`, `[a,b,c]`; `tags=[a,b]` → exactly {ab, abc}; `tags=[a]` → {a, ab, abc}; `tags=[]` → no filter.
3. **type** filter exact.
4. **since/until**: set created_at explicitly to t1<t2<t3; check boundaries are inclusive (`since=t2` includes t2; `until=t2` includes t2), and since+until combined.
5. **team_id**, **indexable** (True and False each), **parent_id** filters.
6. **include_deleted / include_expired / include_history** each default False (excluded) and True (included); expired = expires_at in the past; an expires_at in the future is always included. History = `is_current=false` row.
7. **keywords**: OR semantics ("postgres banana" matches a row with only postgres and a row with only banana), English stemming ("running" matches "runs"), non-matching rows excluded, all-stopword keywords ("the and") → empty results. **preview**: with keywords contains `**<word>**` marker (assert exact preview string for a short content if deterministic); without keywords preview == first 280 chars of content exactly (test with content > 280 chars); keyword preview length ≤ 600. Order preserved under keywords filter (not ranked).
8. **content truncation**: 2500-char content → `content` is exactly first 2000 chars.
9. **order_by / order**: created_at vs updated_at (give them different orderings so the two differ), asc vs desc — assert exact ordered id lists.
10. **limit & pagination**: e.g. 5 rows with distinct created_at, limit=2 → walk pages using `next_cursor` for desc and asc, and for order_by=updated_at. Assert the concatenation of all pages == full ordered list with no gaps/dupes, last page `next_cursor is None`, and `next_cursor` when exactly `limit` rows exist is None. Also verify the decoded `next_cursor` content (`_decode_cursor`) equals the expected (iso timestamp, id) of the expected row. Also test ties: rows with identical created_at.
11. **Invalid cursors** → `JsonRpcError` with code `-32602`, message `"invalid cursor"`, data `{"errors":[{"path":"cursor","message": ...}]}` with message starting `"Invalid cursor format:"`. Try: non-base64 garbage, base64 of non-JSON, base64 of `[]`, base64 of `["x"]`, base64 of `5` / `{"a":1}`, base64 of `["not-a-date", "not-a-uuid"]`.
12. `ctx.deps is None` → `JsonRpcError(-32603, "tool deps not wired")`.
13. **Audit**: use a recording audit stub (or real audit and query `audit_log`) and assert exact kwargs: `action="memory.list"`, `result="success"`, tenant/identity/client/request ids, `details == {"result_count": N, "has_next": bool, "filters_count": K}` — compute K exactly for several filter combos (defaults give 3: deleted, expired, current; each extra filter +1; include_* flags −1 each; cursor +1).
14. Output `request_id == ctx.request_id`; each item's fields (type, tags, version, is_current, deleted_at, expires_at, indexable, embedding_status) match inserted values.
15. Tool class attrs: `name == "memory_list"`, `required_scope == "memory.read"`, `InputModel`/`OutputModel`, description is `TOOL_DESCRIPTIONS["memory_list"]`. Input model: `extra="forbid"`, keywords min/max length (empty string and 513 chars rejected, 512 accepted), limit 0/101 rejected, 1/100 accepted, defaults.
16. Unit: `_encode_cursor(None, id)` raises `ValueError("order_by_value cannot be None")`; encode output exactly equals `base64.urlsafe_b64encode(json.dumps([iso, str(id)]).encode()).decode()`; decode round trip.

## Part B — notices
`src/mem_mcp/plugins/clients/notices.py`, `src/mem_mcp/plugins/notice_delivery.py`. Cover with real DB:
1. `queue()` persists one row with exact tenant_id, plugin_id, kind, template, payload (JSON) ; `expires_at - created_at` ≈ ttl (default 86400 s; custom e.g. 120 s) — assert within ±2 s of exact.
2. Payload with `datetime` (tz-aware and naive), `date`, `UUID`, nested dict/list → stored JSON has exact isoformat strings / str(uuid). Delivered `payload` equals that JSON-decoded dict, and `text` renders them.
3. `deliver_pending`: oldest-first (set created_at explicitly to distinct values, insert in non-sorted order, use ≥5 rows), `limit` respected (limit=2 of 5 returns the 2 oldest; next call returns next 2…), default limit 20 (insert 21 → 20 returned), at-most-once (second call returns []), `delivered_at` set in DB, expired notices (expires_at in past) never delivered and remain undelivered, tenant isolation (tenant B's notices not delivered/marked when delivering A), already-delivered rows skipped.
4. Rendering: `{placeholder}` from payload, missing key → "" + warning logged (`caplog`, message `notice_template_missing_key`, extra key), non-identifier braces left alone, payload stored as a JSON string handled (if the column returns str) — check what asyncpg returns for jsonb in this pool (codec) and test both paths of `isinstance(payload, str)` via a fake conn returning a str payload and an empty-string payload (→ `{}`).
5. `RenderedNotice.to_dict()` exact dict: `{"id": str, "plugin_id", "kind", "text", "payload", "created_at": isoformat}`; `__slots__` content.
6. `_json_default`: datetime → isoformat, date → isoformat, UUID → str, arbitrary object → str(obj).

## Bugs
Do NOT fix source. If the source contradicts the contract, write the test asserting CORRECT behaviour with `@pytest.mark.xfail(strict=True, reason="BUG: ...")` and make sure it xfails deterministically (if a test is flaky, don't strict-xfail it — tell me). Things I suspect — please investigate each and report concretely what you observed:
- (a) `next_cursor` is built from the overflow row `rows[limit]` while the keyset predicate is strict `<`/`>` — the next page may skip one row.
- (b) Cursor value is passed as an ISO **string** to compare against a timestamptz column — asyncpg may reject it (DataError) so a second page may fail entirely.
- (c) ORDER BY uses `created_at DESC, id` (id always ASC) while the keyset predicate compares the row `(created_at, id)` with `<` — rows with tied timestamps may be skipped/duplicated in desc order.
- (d) `_decode_cursor` doesn't catch `TypeError`/`KeyError` (e.g. base64 of `5` or `{"a":1}`), and a decodable but non-timestamp/non-uuid cursor reaches SQL — these should be -32602 but may surface as other errors.
- (e) Description promises `team_id` accepts a team name or `"*"`, but the input model is `UUID | None` — check whether anything upstream (transport/dispatcher) translates it; if not, this is a contract bug.
- (f) `deliver_pending` orders in a subquery but `UPDATE ... RETURNING` order is not guaranteed — check whether results are oldest-first reliably (run the ordering test many times, e.g. `pytest --count` isn't available, so loop in-test or rerun 10×).
- (g) negative/zero `ttl_seconds` behaviour.

## Acceptance
- Run: `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <your 4 new files>` — all pass/xfail. Run it **3 times** and also once with `-p xdist -n 4` if pytest-xdist is installed (to check parallel isolation). Report exact results.
- `ruff check tests` and `mypy` clean for the new files (or report what mypy config covers).
- Runtime of the new files: report seconds.
- Report: files added, test counts, every xfail with its reason and the evidence, and anything you couldn't test.
