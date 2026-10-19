# Work order 1 — Behavioural test suite for `memory_list` and the plugin-notice pipeline

## Goal
Write **new test files only** that thoroughly pin down the behaviour of three modules. The suite will be
scored by **mutation testing (mutmut)** restricted to these modules, so every assertion should be exact
(exact id sets / ordered id lists, exact strings, exact error codes, exact dicts) — not "doesn't crash".

Modules under test:
1. `src/mem_mcp/mcp/tools/list.py` — `MemoryListTool`, `MemoryListInput/Item/Output`, `_encode_cursor`, `_decode_cursor`.
   Behavioural contract: `TOOL_DESCRIPTIONS["memory_list"]` in `src/mem_mcp/mcp/tool_descriptions.py`.
2. `src/mem_mcp/plugins/clients/notices.py` — `NoticeClientImpl.queue`, `_json_default`.
3. `src/mem_mcp/plugins/notice_delivery.py` — `deliver_pending`, `_render`, `RenderedNotice.to_dict`.

## Hard rules
- **Do NOT modify anything under `src/`, `alembic/`, existing tests, any `conftest.py`, or `pyproject.toml`.** New files only.
- Suggested files: `tests/integration/test_memory_list_behaviour.py`, `tests/integration/test_plugin_notices_behaviour.py`,
  `tests/unit/test_memory_list_units.py`, `tests/unit/test_notice_units.py` (names are up to you; must be new).
- Tests must pass on the current unmodified source.
- Tests run hundreds of times in **parallel worker processes against one shared DB**: create your own tenant/team/identity/
  oauth client with UUID-suffixed names per test (or per module fixture), never assume empty tables, never depend on
  order between tests, no wall-clock races (no sleeps; don't rely on two inserts getting different `now()`).
  Clean up what you create. Keep the whole new suite fast (a few seconds).
- No network. Use a stub embedder (see `_build_deps()` in `tests/integration/test_mindmap_e2e.py`) if you use `MemoryWriteTool`.
- Use the `pg_pool` fixture from `tests/conftest.py`. Follow the setup/cleanup pattern of
  `tests/integration/test_mindmap_e2e.py` (`_setup`, `_cleanup`, `_ctx`) — tenant + team + `assign_role` +
  primary `tenant_identities` row with `default_team_id` + `oauth_clients` row for the ToolContext `client_id`.
- **Deterministic data**: I strongly recommend inserting memories (via `MemoryWriteTool` or direct SQL — check the
  `memories` schema in `alembic/versions/` for required columns) and then setting `created_at`, `updated_at`,
  `expires_at`, `deleted_at`, `is_current`, `version`, `indexable`, `parent_id`, `team_id`, `tags`, `type` with
  direct `UPDATE`s on a plain pool connection to fixed, distinct values (e.g. 2024-01-01 + n minutes) so ordering
  is fully deterministic. Same for `plugin_notices.created_at` / `expires_at` when testing ordering/expiry.
  (Check for triggers that might override `updated_at` on UPDATE; if one exists, work around it, e.g. set it in the
  same statement and verify by reading back.)

## What to cover — `memory_list` (DB-backed, real tool call)
For each item, assert the **exact set/list of returned ids**, using data that includes both matching and
non-matching rows:
- **Tenant scoping**: memories from a second tenant never appear.
- **tags**: AND semantics — `tags=["a","b"]` returns only memories with both (not `["a"]`, `["b"]`, `["a","c"]`);
  a single tag; a tag nobody has → empty; `tags=[]` behaves like no filter.
- **type**, **since** (inclusive `>=` — include a row exactly at the boundary), **until** (inclusive `<=` — boundary row), both combined.
- **team_id**, **indexable** (True and False separately), **parent_id**.
- **include_deleted**, **include_expired** (expired = `expires_at` in the past; future `expires_at` is always included),
  **include_history** (`is_current=false` rows) — each default-off and on.
- **keywords**: lenient OR, English stemmed (e.g. keyword "running" matches content "runs"; "postgres zebra" matches a
  row containing only "postgres"); non-matching rows excluded; an all-stopword input (e.g. "the") returns nothing.
  **preview**: with keywords, contains `**<match>**` markers (look up `HEADLINE_OPTIONS`, `PREVIEW_MAX_CHARS`,
  `PREVIEW_FALLBACK_CHARS`, `HEADLINE_SOURCE_MAX_CHARS` in `src/mem_mcp/memory/hybrid_query.py` and assert exact
  values/lengths where feasible); without keywords preview == `content[:PREVIEW_FALLBACK_CHARS]` exactly.
  Preview length bound `<= PREVIEW_MAX_CHARS` with long content.
- **content truncation**: a 2500-char body returns exactly the first 2000 chars; a short body returned verbatim.
- **Output fields**: assert exact values of `type`, `tags`, `version`, `is_current`, `deleted_at`, `expires_at`,
  `indexable`, `embedding_status`, `created_at`, `updated_at` for a known row; `request_id == ctx.request_id`.
- **order_by / order**: all four combinations, with created_at order differing from updated_at order so a mutant
  swapping columns or directions is caught. Assert exact ordered id lists.
- **limit** and **next_cursor**: `limit=N` with exactly N rows → `next_cursor is None`; N+1 rows → cursor present.
  Walk the full pagination for asc and desc and for both order_by values; assert the concatenated pages equal the
  full expected ordered list with **no duplicates and no gaps**. Also assert what `next_cursor` decodes to
  (`_decode_cursor`) — which row's timestamp/id it encodes.
  Include a case with **tied `created_at`** across rows (same timestamp, different ids).
- **Invalid cursor** → `JsonRpcError` with `code == -32602`, message `"invalid cursor"`, and
  `data == {"errors": [{"path": "cursor", "message": <starts with "Invalid cursor format:">}]}`. Try several malformed
  inputs: non-base64 garbage, base64 of non-JSON, base64 of `[]` / `["x"]`, base64 of `{}`, base64 of `5`,
  base64 of `["not-a-timestamp", "<uuid>"]`, base64 of `["<valid iso>", "not-a-uuid"]`. (Check `JsonRpcError` in
  `src/mem_mcp/mcp/errors.py` for attribute names.)
- `ctx.deps is None` → `JsonRpcError` code `-32603`.
- **Audit call**: use a recording audit logger (subclass/duck-type `NoopAuditLogger` from `mem_mcp.audit.logger`) and
  assert the exact kwargs: `action="memory.list"`, `result="success"`, tenant_id, identity_id, client_id, request_id,
  and `details == {"result_count": ..., "has_next": ..., "filters_count": ...}`. Pin `filters_count` exactly for
  several inputs (defaults → 3: deleted/expired/history clauses; all include_* True and no filters → 0; with
  type+tags+keywords etc.; with a cursor — the cursor predicate counts too). Also assert `has_next` True/False.

### Unit-level (no DB) for list.py
- `_encode_cursor(None, id)` raises `ValueError("order_by_value cannot be None")` (exact message).
- `_encode_cursor(dt, id)` produces exactly `urlsafe_b64encode(json.dumps([dt.isoformat(), str(id)]))`; round trip with `_decode_cursor`.
- `_decode_cursor` error messages start with `"Invalid cursor format: "`.
- `MemoryListInput`: `extra="forbid"` rejects unknown fields; `keywords` min_length 1 / max_length 512 boundaries
  (512 ok, 513 rejected, "" rejected); limit 1 ok / 0 rejected / 100 ok / 101 rejected; default values of every field
  (including `keywords`, `team_id`, `indexable`, `parent_id`, `include_expired`); all 7 MemoryType literals accepted.
- `MemoryListTool.name == "memory_list"`, `required_scope == "memory.read"`, description is `TOOL_DESCRIPTIONS["memory_list"]`,
  `InputModel`/`OutputModel` are the right classes.

## What to cover — notices (DB-backed)
- `NoticeClientImpl(pool, tenant, plugin_id).queue(kind, template, payload)` inserts exactly one row with those
  tenant_id / plugin_id / kind / template / payload, `delivered_at IS NULL`.
- Default TTL: `expires_at - created_at == interval '86400 seconds'` exactly (check whether `created_at` defaults to
  `now()` — if so both are the same transaction `now()` and equality is exact). Custom `ttl_seconds=60` → exactly 60s.
- Payload containing `datetime` (tz-aware), `date`, `UUID`, nested dict/list, and e.g. `Decimal` → stored JSON equals
  the exact expected dict (datetime/date → `.isoformat()`, others → `str()`); queue does not raise.
- Logging: `plugin_notice_queued` info record with `plugin_id` and `kind` extras (caplog, check record attributes).
- `deliver_pending(conn, tenant)`:
  - returns rendered notices **oldest first** (set distinct `created_at` explicitly); exact ordered ids.
  - `limit`: with 3 pending and `limit=2` returns the 2 oldest; next call returns the remaining one; default limit is
    20 (queue 21 → first call returns exactly 20 oldest).
  - **at-most-once**: second call returns `[]`; `delivered_at` is set on delivered rows and still NULL on undelivered ones.
  - **expiry**: rows with `expires_at <= now()` are not returned and stay undelivered.
  - **tenant isolation**: other tenant's pending notices neither returned nor marked delivered.
  - Template rendering end-to-end: `{name}` substituted from payload; missing key → empty string + warning log
    `notice_template_missing_key` with `key` and `template` (truncated to 120 chars — test with a >120-char template)
    extras; datetime payload values render as their isoformat string.
  - Returned `RenderedNotice` fields: id, plugin_id, kind, text, payload (dict, equal to stored), created_at.
  - Payload stored as JSON string vs dict: cover the `isinstance(payload, str)` branch (default asyncpg returns jsonb
    as str) and an empty-payload `{}` case.
- `RenderedNotice.to_dict()` — exact dict: `{"id": str(id), "plugin_id", "kind", "text", "payload", "created_at": iso}`;
  `__slots__` (assigning an unknown attribute raises AttributeError).
- `_render` unit cases beyond `tests/unit/test_notice_delivery.py`: repeated placeholder, adjacent placeholders,
  `None` value → `"None"`, key starting with underscore, uppercase keys, `{ a }` (spaces) not a placeholder,
  `{{a}}` behaviour (assert whatever it actually does is consistent with the regex).

## Suspected bugs — verify empirically
Please check each of these against the real DB. For each one that is real, write a test asserting the **correct**
behaviour and mark it `@pytest.mark.xfail(strict=True, reason="BUG: <one line>")`. Separately keep a passing test
that pins the current behaviour only where it's not the buggy part. If a suspicion is wrong, just write a normal
passing test and tell me.
1. **Pagination skips a row at every page boundary**: `next_cursor` is built from `rows[inp.limit]` (the first row
   of the *next* page), and the next page uses a strict `<`/`>` predicate, so that row is never returned.
2. **Tie-break direction mismatch**: ORDER BY is `created_at DESC, id` (id ASC) but the keyset predicate is a row
   comparison `(created_at, id) < (...)` (id DESC) — with tied timestamps, pages may skip/duplicate rows.
3. **Cursor timestamp passed as an ISO string** to a timestamptz comparison — check whether asyncpg even accepts it
   (pagination with a cursor may raise a DataError instead of working at all). If cursor pages crash, that is a bug.
4. **Malformed-but-decodable cursors not mapped to -32602**: `{}` (KeyError), `5` (TypeError), a bad timestamp or
   bad uuid inside a well-formed cursor (DB error) — likely escape as non-JsonRpcError exceptions.
5. **Contract mismatch on `team_id`**: the description says `team_id` accepts a UUID **or team name**, and
   `team_id="*"` for cross-team queries; `MemoryListInput.team_id` is `UUID | None`, so these are rejected.
6. Anything else you discover.

Report each bug with a one-line explanation and its test name.

## Acceptance / verification
- `ruff check tests` and `mypy` clean for your new files (or report any issue you couldn't resolve).
- Run: `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <your new files>`
  — all pass (xfails counted as xfailed, no XPASS).
- Run your new files 3 times in a row and once with `-p xdist -n 4` if pytest-xdist is installed (to prove isolation);
  report results.
- Run the full suite `pytest -q` and report pass/fail counts; confirm no new failures vs. baseline.
- `git status` must show only new files under `tests/`.

Report: files added, test counts, exact command outputs (summary lines), the list of confirmed bugs, and any suspicion that turned out false.
