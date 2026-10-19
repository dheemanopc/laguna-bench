# Order 1 — Behaviour test suite for `memory_list` and plugin notices (TESTS ONLY)

## Goal
Write a thorough, behaviour-focused test suite for three modules. **Do not modify anything under
`src/`, `alembic/`, existing tests, any `conftest.py`, or `pyproject.toml`.** Add NEW test files only.

Modules under test:
1. `src/mem_mcp/mcp/tools/list.py` — `MemoryListTool`, `MemoryListInput`/`MemoryListItem`/`MemoryListOutput`,
   `_encode_cursor`/`_decode_cursor`. Behavioural contract: `TOOL_DESCRIPTIONS["memory_list"]` in
   `src/mem_mcp/mcp/tool_descriptions.py`.
2. `src/mem_mcp/plugins/clients/notices.py` — `NoticeClientImpl.queue`, `_json_default`.
3. `src/mem_mcp/plugins/notice_delivery.py` — `deliver_pending`, `_render`, `RenderedNotice.to_dict`.

The suite will be scored by **mutation testing (mutmut) restricted to these three modules**: the score
is the fraction of mutants killed. So assert precisely on observable behaviour: exact id sets/orders,
exact strings, exact error codes/messages/data, exact audit `details` dicts, exact log records — not
"doesn't crash". Every string/number/operator in these modules is a mutant candidate; aim to have
some test that fails if any of them changes.

## Files to create
- `tests/integration/test_memory_list_behaviour.py` (DB-backed, real Postgres)
- `tests/unit/test_memory_list_contract.py` (pure / mocked: cursor helpers, input model validation,
  SQL/params shape via a fake conn if useful, audit details, deps-missing error)
- `tests/integration/test_plugin_notices_behaviour.py` (DB-backed queue + delivery)
- `tests/unit/test_plugin_notices_contract.py` (pure: `_render`, `_json_default`, `RenderedNotice.to_dict`, log records via `caplog`)

## Isolation / determinism requirements (critical)
Tests run hundreds of times, in parallel worker processes, against ONE shared database.
- Use the `pg_pool` fixture from `tests/conftest.py`. Create your own tenant + team + primary identity
  (with `default_team_id`) + `oauth_clients` row per test (or per module-scoped helper), with
  UUID-suffixed emails/names. Follow `tests/integration/test_mindmap_e2e.py` for the setup pattern.
- Never assume empty tables; always filter/assert only within your own tenant.
- No wall-clock races. For time-dependent behaviour (since/until, ordering, expiry) set timestamps
  explicitly via direct SQL UPDATE of `created_at`/`updated_at`/`expires_at`/`deleted_at` on your own
  rows (use the maintenance/system connection pattern the existing tests use to bypass RLS), using
  values well apart (e.g. hours/days) — do not rely on `sleep`.
- To create memories you may use `MemoryWriteTool` with a stub embedder (see existing tests for stub
  embedders), or direct INSERTs into `memories` — whichever is simpler and robust. Direct INSERT gives
  you full control over `type`, `tags`, `team_id`, `indexable`, `parent_id`, `is_current`, `version`,
  `deleted_at`, `expires_at`, timestamps.
- No network. Whole new suite should run in seconds.
- Audit: use a recording fake audit logger (in `ToolDeps`) to capture the audit call kwargs, so you can
  assert them exactly.

## Behaviour to pin down — memory_list
- Tenant scoping: another tenant's memories never appear.
- `tags`: AND semantics — memory must carry ALL requested tags (a memory with only one of two
  requested tags is excluded; superset of tags is included).
- `type`, `since` (inclusive, `>=`), `until` (inclusive, `<=`) — test boundary rows exactly equal to
  since/until, plus rows just outside.
- `team_id`, `indexable` (True and False separately), `parent_id`.
- `include_deleted`, `include_expired` (expires_at in past excluded by default; future/NULL included),
  `include_history` (is_current=false excluded by default).
- `keywords`: lenient OR, English-stemmed (e.g. "running" matches "runs"/"run"); non-matching rows
  excluded; all-stopword input (e.g. "the") returns nothing; `preview` contains `**match**` markers
  around the matched word when keywords passed; without keywords `preview` is the head of content
  (check exact value against the `PREVIEW_FALLBACK_CHARS` constant from `mem_mcp.memory.hybrid_query`
  with a long content); keywords does not change order.
- `content` truncated to exactly 2000 chars for long bodies; short content unchanged.
- `order_by` created_at vs updated_at (make the two orders differ), `order` asc vs desc — assert exact id
  order.
- `limit`: exactly `limit` results; `next_cursor` is None when results fit exactly (e.g. 3 rows, limit 3)
  and non-None when there are more.
- Pagination: walk pages with `next_cursor` and assert that the union of pages equals the full set
  exactly, with no duplicates and **no skipped rows**, for both asc and desc and for both order_by
  values. Also test pages where several rows share an identical `created_at` (tie broken by id).
- Invalid cursors → `JsonRpcError` with code `-32602`, message `"invalid cursor"`, and `data` errors
  path `"cursor"`. Try: non-base64 garbage, base64 of non-JSON, base64 of JSON `[]` / `["x"]`, base64 of
  a JSON object `{"a":1}`, base64 of a JSON number `5`, base64 of `["not-a-date", "<uuid>"]`,
  base64 of `["<valid iso>", "not-a-uuid"]`.
- Empty-string cursor behaves like no cursor.
- Input model: `extra="forbid"`; `limit` bounds 1..100 (0 and 101 rejected, 1 and 100 accepted);
  `keywords` min_length 1 / max_length 512; invalid `type`/`order`/`order_by` rejected; defaults
  (limit 25, order desc, order_by created_at, include_* False).
- The tool description contract says `team_id` accepts "UUID or team name" and `team_id="*"` for
  cross-team queries — test what actually happens.
- `ctx.deps is None` → `JsonRpcError(-32603, "tool deps not wired")`.
- Audit: exactly one call with `action="memory.list"`, `result="success"`, tenant/identity/client/request ids
  from ctx, and `details == {"result_count": N, "has_next": bool, "filters_count": K}` — compute K exactly
  for several filter combinations (defaults give 3: deleted/expired/current clauses; each include_* flag
  removes one; each filter / keywords / cursor predicate adds one).
- Output: `request_id` echoes ctx; class attributes `name == "memory_list"`, `required_scope == "memory.read"`,
  `description == TOOL_DESCRIPTIONS["memory_list"]`.
- `_encode_cursor(None, id)` raises ValueError; `_encode_cursor`/`_decode_cursor` round-trip exactly.

## Behaviour to pin down — notices
- `queue()`: row persisted with exact tenant_id, plugin_id, kind, template, payload; `expires_at - created_at`
  ≈ ttl_seconds (default 86400; test a custom ttl too; compare with a tolerance of a second or two — these
  are both set by `now()` in the same statement so should be exact).
- Payloads with `datetime` (tz-aware and naive), `date`, `UUID`, nested dicts/lists → stored JSON values
  exactly equal `isoformat()` / `str()`.
- `_json_default` directly: datetime → isoformat, date → isoformat, UUID → str, arbitrary object → str(obj).
- `log.info("plugin_notice_queued", extra=...)` record with plugin_id/kind (caplog).
- `deliver_pending`: oldest-first by created_at (set created_at explicitly); `limit` respected (default 20 —
  queue 21+ and check 20 returned); at-most-once (second call returns none of the already delivered);
  expired notices (expires_at <= now) not delivered; delivered_at set in DB after delivery; tenant
  isolation (other tenant's notices untouched and not returned); empty list when nothing pending.
- `_render`: `{key}` substitution, multiple keys, repeated keys, missing key → "" and a warning record
  `notice_template_missing_key` with `extra` key/template (template truncated to 120 chars — test with a
  >120-char template), non-identifier braces like `{1abc}`/`{ key }`/`{}` left untouched, non-string
  values rendered via `str()`.
- `RenderedNotice.to_dict()`: exact dict (id as str, created_at isoformat, payload passthrough).
- Payload returned by `deliver_pending` is a dict (handles str jsonb too — use a fake conn returning a
  str payload, and an empty string payload → `{}`).

## Bugs
If a test of the CONTRACT (tool description / docstrings / work-order behaviour above) fails on the
current source, do NOT fix the source. Keep the test asserting the correct behaviour and mark it
`@pytest.mark.xfail(strict=True, reason="BUG: <one-line explanation>")`. Keep bug tests minimal and
separate from the passing tests so a bug doesn't hide other assertions. Suspected issues to verify
empirically (don't assume — confirm by running):
- Pagination may skip a row between pages (cursor appears to be built from the overflow row while the
  predicate is strict).
- The cursor value is passed to SQL as an ISO string — check whether paging with a cursor works at all.
- Cursor tie-breaking: ORDER BY uses `id` ascending even when order is desc, while the keyset predicate
  compares the `(ts, id)` row tuple — check tied-timestamp pagination in desc order.
- Malformed-but-decodable cursors (JSON object, number, bad timestamp, bad uuid) may not map to -32602.
- `team_id` as team name / `"*"` per the description.

## Acceptance
- Run: `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <your new files>` — all pass (xfails strict count as passing). Run your new files 3 times in a row to confirm determinism, and also once with `-p xdist -n 4` if pytest-xdist is installed.
- Run the full suite `pytest -q` and report pass/fail counts; confirm no new failures vs baseline.
- `ruff check tests` and `mypy` clean on the new files (or report exactly what remains).
- Report: files added, exact test command outputs (counts), and a list of every xfail bug with a one-line explanation and how you confirmed it.
