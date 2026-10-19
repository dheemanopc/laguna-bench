# Work order 1 — Test suite for `memory_list` and the plugin-notice pipeline (TESTS ONLY)

## Goal
Write a thorough, behaviour-focused test suite for three modules. The suite will be scored by
**mutation testing (mutmut)** restricted to these modules, so every assertion must be precise
(exact values, exact sets/orderings, exact error codes/messages/data, exact SQL params where
relevant) — never just "doesn't crash".

Modules under test:
1. `src/mem_mcp/mcp/tools/list.py` — `MemoryListTool`, `MemoryListInput`, `MemoryListItem`,
   `MemoryListOutput`, `_encode_cursor`, `_decode_cursor`. The behavioural contract is the
   `"memory_list"` entry in `src/mem_mcp/mcp/tool_descriptions.py`.
2. `src/mem_mcp/plugins/clients/notices.py` — `NoticeClientImpl.queue`, `_json_default`.
3. `src/mem_mcp/plugins/notice_delivery.py` — `deliver_pending`, `_render`, `RenderedNotice.to_dict`.

## Hard rules
- **Do NOT modify anything under `src/`, `alembic/`, `pyproject.toml`, any `conftest.py`, or any
  existing test file.** Add NEW test files only. Suggested files:
  - `tests/unit/test_memory_list_contract.py` — mock-conn tests (no DB) of SQL/params/audit/cursor/model.
  - `tests/integration/test_memory_list_db.py` — real-DB behaviour tests via `pg_pool`.
  - `tests/unit/test_notice_pipeline_contract.py` — fake-conn tests of queue/deliver/render/to_dict.
  - `tests/integration/test_plugin_notices_db.py` — real-DB queue → deliver tests.
- All new tests must PASS on the current unmodified source.
- Mutation testing runs the tests hundreds of times, in parallel processes, against ONE shared DB:
  - Create your own tenants/teams/clients per test (or per module fixture) with UUID-suffixed
    emails/names/client ids. Never assume a table is empty; always scope assertions to your
    own tenant's rows/ids. No dependence on test order. Clean up what you create where practical.
  - No wall-clock races: when time ordering matters, set `created_at`/`updated_at`/`expires_at`
    explicitly (e.g. fixed offsets from `now()` like `now() - interval '3 hours'`), don't sleep.
  - Keep the whole new suite fast (a few seconds total). No network. If you need an embedder,
    use a stub (see existing tests); direct SQL inserts into `memories` via `system_tx` are
    preferred for DB tests because they let you set every column (created_at, updated_at,
    deleted_at, expires_at, is_current, version, indexable, parent_id, team_id, tags, type).
    Inspect the `memories` table columns/constraints (alembic migrations, or query
    `information_schema`) to get required columns right.
- DB setup pattern: see `tests/integration/test_mindmap_e2e.py` (tenant + team + `assign_role` +
  primary `tenant_identities` row with `default_team_id` + `oauth_clients` row for the ctx
  `client_id`). The `pg_pool` fixture is in `tests/conftest.py` (it registers the jsonb codec
  via `_init_connection`). `tenant_tx`/`system_tx` live in `mem_mcp.db`.
- Existing related tests to look at (don't edit): `tests/unit/test_tools_list.py`,
  `tests/unit/test_search_preview_lenient.py`, `tests/unit/test_notice_delivery.py`,
  `tests/unit/test_notice_client_serialization.py`.

## Bugs: do not fix, pin with strict xfail
If correct behaviour (per the tool description / docstrings) differs from actual behaviour,
write the test asserting the CORRECT behaviour and mark it
`@pytest.mark.xfail(strict=True, reason="BUG: <one line>")`. Only do this when the failure is
**deterministic** (it must fail every single run, otherwise strict xfail flakes). Keep a list of
every bug for your report. Suspects I want you to investigate concretely (verify each; don't
assume I'm right):
1. **Pagination skips a row per page**: `next_cursor` is encoded from `rows[limit]` (the first
   row NOT returned), but the next page uses a strict `<`/`>` keyset predicate, so that row may
   never be returned. Test: N rows with distinct created_at, page through with small `limit`,
   assert the union of pages == all N ids exactly once, in order.
2. **Cursor predicate binds the ISO string as a timestamptz param** — asyncpg may reject a `str`
   for a timestamptz parameter (DataError), meaning following any `next_cursor` crashes. Find
   out what actually happens on a real DB.
3. **Tie-break direction**: `ORDER BY created_at DESC, id` (id ASC) vs row-comparison
   `(created_at, id) < (...)` which assumes id DESC — rows sharing a created_at can be
   skipped/duplicated across pages in desc order.
4. **Malformed-but-valid-JSON cursors** — e.g. base64 of `{}` (KeyError), `5` / `null`
   (TypeError), or a list whose 2nd element is not a UUID / 1st is not a timestamp — are not
   converted to JSON-RPC `-32602`; they surface as other exceptions. Contract: invalid cursor
   → `JsonRpcError` code `-32602`, message `"invalid cursor"`, `data["errors"][0]["path"] == "cursor"`.
   (Also verify the correctly-handled cases: non-base64 garbage, base64 of non-JSON, base64 of
   `[]`/`["x"]` → -32602.)
5. **`team_id` contract mismatch**: description says `team_id` accepts "UUID or team name" and
   `"*"` for cross-team, but `MemoryListInput.team_id` is `UUID | None` (validation error).
6. **Notice payload double-encoding with the jsonb codec**: `queue()` passes
   `json.dumps(payload)` to `$5::jsonb`; on a pool with the jsonb codec (prod pool and `pg_pool`)
   that may store a JSON *string* scalar rather than an object. Check
   `SELECT jsonb_typeof(payload)` for a row queued via `pg_pool`; the correct behaviour is
   `'object'`. Also check what `deliver_pending` returns as `payload` (must be a dict equal to
   the serialized payload).
7. **`deliver_pending` ordering**: `ORDER BY` is only in the subquery; `UPDATE ... RETURNING`
   doesn't guarantee order, but the docstring promises oldest-first. Try to construct a
   deterministic counterexample (e.g. insert rows whose physical order differs from created_at
   order). Only xfail if it fails deterministically over many repeated runs; otherwise write the
   passing oldest-first test and just mention the risk in your report.
Report anything else you find too.

## What to cover (be exhaustive; precision kills mutants)

### memory_list — unit (mock conn; patch `mem_mcp.mcp.tools.list.tenant_tx` like test_tools_list.py)
Capture `conn.fetch(query, *params)` and assert:
- Default call: params exactly `[tenant_id, 26]`; SQL contains `tenant_id = $1`,
  `deleted_at IS NULL`, `(expires_at IS NULL OR expires_at > NOW())`, `is_current = true`,
  `ORDER BY created_at DESC, id`, `LIMIT $2`, `LEFT(content, 2000) AS content`,
  `LEFT(content, 280) AS preview` (no keywords).
- Each include_* flag drops exactly its clause; each filter (type, tags, since, until, team_id,
  indexable incl. `indexable=False`, parent_id, keywords) adds its clause with the right `$n`
  index and the param value in the right position; combined filters → exact param list order.
  `until` and `since` both filter `created_at` (`>=` / `<=`).
- keywords: preview select uses `ts_headline('english', LEFT(content, 8000)`, the headline
  options string, fallback `LEFT(content, 280)`, outer cap `600`.
- order_by/order combos → exact ORDER BY strings (`updated_at ASC, id`, etc.).
- `limit=N` → last param `N+1`; with N+1 rows returned → N results, `next_cursor` decodes to
  `[rows[N].<order col>.isoformat(), str(rows[N].id)]` (check both created_at and updated_at
  order_by, with distinct created_at/updated_at values); with exactly N rows → `next_cursor is None`.
- Valid cursor: predicate `(created_at, id) < ($k, $k+1::uuid)` for desc, `>` for asc,
  `updated_at` column when order_by=updated_at; params carry the decoded iso string and id string.
- Invalid cursor → `JsonRpcError` exact code/message/data (incl. the message string starting
  `"Invalid cursor format:"`); fetch NOT called.
- `ctx.deps is None` → `JsonRpcError(-32603, "tool deps not wired")`.
- Audit: use a recording audit fake; assert called once with the conn, `action="memory.list"`,
  `result="success"`, tenant_id/identity_id/client_id/request_id from ctx, and
  `details == {"result_count": ..., "has_next": ..., "filters_count": ...}` exact for several
  scenarios (default → filters_count 3; all include_* true and no filters → 0; with filters/cursor → exact count).
- Output: `request_id` echoed; items mapped field-for-field.
- Class attributes: `name == "memory_list"`, `required_scope == "memory.read"`,
  `description == TOOL_DESCRIPTIONS["memory_list"]`, `InputModel`/`OutputModel`.
- `MemoryListInput`: all defaults (incl. `include_expired`, `indexable`, `parent_id`, `team_id`,
  `keywords`), `extra="forbid"`, keywords min_length 1 / max_length 512 boundaries, limit 1 and
  100 ok / 0 and 101 rejected, all 7 valid types accepted.
- `_encode_cursor`: exact output for a known datetime+uuid (compare to
  `base64.urlsafe_b64encode(json.dumps([iso, str(id)]).encode()).decode()`), `None` →
  `ValueError("order_by_value cannot be None")`. `_decode_cursor` round trip and error cases.

### memory_list — DB integration (real `pg_pool`, real `tenant_tx`, real MemoryListTool)
Use exact id sets/orderings for your own tenant:
- tenant scoping (second tenant's memories never appear);
- tags AND semantics: memories with `[a,b]`, `[a]`, `[b]`, `[a,b,c]`, `[]` → `tags=[a,b]` returns
  exactly `{[a,b],[a,b,c]}`; single tag; tags=[] behaves as no filter (empty list is falsy);
- type; since/until boundaries (inclusive) on explicit created_at; team_id (two teams);
  indexable True/False; parent_id;
- include_deleted / include_expired / include_history (non-current version rows) each off/on;
- keywords: OR semantics across words, stemming (e.g. "running" matches "runs"), non-matching
  word excluded, all-stopword keywords ("the a") → no results; `preview` contains `**term**`
  markers when keywords passed; without keywords preview == `content[:280]` exactly; long
  content (>2000 chars) → `content` length exactly 2000 and equals prefix;
- order_by created_at vs updated_at with deliberately different orderings; asc vs desc;
- limit and next_cursor present/absent; full pagination walk (suspect 1/2/3 above);
- an audit row or recording audit fake (whichever the deps pattern allows) shows the call.

### Notices — unit (fake conn / fake pool)
- `_json_default`: datetime → isoformat with `T`, date → isoformat, UUID → str, other (e.g.
  Decimal) → str. `json.dumps(..., default=_json_default)` exact strings.
- `NoticeClientImpl.queue` with a fake `system_tx` (patch `mem_mcp.plugins.clients.notices.system_tx`):
  exact execute args: tenant_id, plugin_id, kind, template, exact JSON string of payload
  (datetimes/dates/UUIDs nested), `str(ttl_seconds)` with default `"86400"` and custom value;
  log record `plugin_notice_queued` with `plugin_id`/`kind` extras.
- `deliver_pending` with a fake conn: params `(tenant_id, 20)` default and custom limit; payload
  str → parsed; empty string payload → `{}`; dict payload passed through; rendered text; order
  of returned objects mirrors rows; empty rows → `[]`.
- `_render`: placeholders, repeated placeholder, missing key → "" plus warning record with
  `extra` key/template (template truncated to 120 chars — assert exact), non-identifier braces
  untouched, values via `str()` (None → "None", ints, nested).
- `RenderedNotice.to_dict`: exact dict (id str, created_at isoformat, payload identity), `__slots__`.

### Notices — DB integration (`pg_pool`)
- queue then read the raw row: kind/template/plugin_id/tenant; `expires_at - created_at`
  exactly `86400s` default and custom TTL (both use the same `now()`; verify).
- datetime/date/UUID payload queues without error and round-trips through `deliver_pending`.
- oldest-first (set created_at explicitly), `limit`, at-most-once (second call returns none of
  the same ids), expired notices (expires_at in past, e.g. ttl negative or update row) never
  delivered, tenant isolation (tenant B's pending notices untouched and still deliverable to B),
  already-delivered rows skipped; rendered text with `{placeholder}` incl. missing keys;
  `to_dict()` shape on a real delivered notice.
- Run `deliver_pending` inside `system_tx(pool)` (that's how it's called).

## Verification (report exact output)
1. `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py tests/unit/test_search_preview_lenient.py <your new files>` — all pass/xfail.
2. Run your new files **5 times** in a row and also once with `-p no:randomly` if available /
   in reverse order (`pytest ... ` then reversed file order) to show determinism; report timings.
3. Run two copies concurrently against the DB (e.g. `pytest <new files> & pytest <new files>; wait`)
   to show parallel-safety.
4. `ruff check tests/<your new files>`.
5. Full suite `pytest -q` — report pass/fail counts and confirm no new failures vs. baseline
   (`git stash` is NOT allowed to touch src; just compare: failures must be in pre-existing files only).
6. Confirm `git status` shows only new test files.

Report: files added, test counts, every bug found (one line each, with the xfail test name),
any suspect you investigated that turned out NOT to be a bug (and why), and anything uncertain.
