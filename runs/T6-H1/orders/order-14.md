# Work order 14 — remaining unit gaps: memory_list audit edge + notice unit tightening (TESTS ONLY)

Keep output short.

## A. `tests/unit/test_memory_list_sql_exact.py` (add)
1. Audit for the all-filters + cursor scenario (type, tags, since, until, team_id, indexable=False,
   parent_id, keywords, cursor, limit=7, 0 rows): assert `details == {"result_count": 0, "has_next": False, "filters_count": N}`
   with N the actual exact count (expected 12 = 3 default clauses + 8 filters + 1 cursor predicate).
2. `deps=None` AND `cursor="not-base64!!!"` → `JsonRpcError.code == -32603` (deps check precedes cursor parsing).
3. `tags=[]` (empty list) → params `[tenant, 26]` and `"tags @>" not in query`.
4. `cursor=""` (empty string) → no cursor predicate (`"::uuid" not in query`), params `[tenant, 26]`.

## B. New file `tests/unit/test_notice_exact.py`
1. `queue` exact JSON: patch `mem_mcp.plugins.clients.notices.system_tx` with an asynccontextmanager that
   records the pool argument and yields a fake conn recording `execute(query, *args)`.
   Payload `{"fire_at": datetime(2026,6,15,10,30,tzinfo=UTC), "d": date(2026,6,15), "id": UUID("12345678-1234-5678-1234-567812345678"), "n": 1, "nested": {"when": datetime(2026,1,1,tzinfo=UTC), "ids": [UUID("12345678-1234-5678-1234-567812345678")]}}`.
   Assert `args[4] == '{"fire_at": "2026-06-15T10:30:00+00:00", "d": "2026-06-15", "id": "12345678-1234-5678-1234-567812345678", "n": 1, "nested": {"when": "2026-01-01T00:00:00+00:00", "ids": ["12345678-1234-5678-1234-567812345678"]}}'`
   exactly; `args[:4] == (tenant, "plugin-x", "kind-x", "tmpl-x")`; `args[5] == "86400"`; exactly one execute;
   recorded pool `is` the pool passed to `NoticeClientImpl`.
   Also `ttl_seconds=0` → `args[5] == "0"`; `ttl_seconds=-5` → `"-5"`.
   Assert query contains `"INSERT INTO plugin_notices"`, `"(tenant_id, plugin_id, kind, template, payload, expires_at)"`,
   `"$5::jsonb"`, `"now() + ($6 || ' seconds')::interval"`.
2. Log: with `caplog.at_level(logging.INFO, logger="mem_mcp.plugins.clients.notices")` → exactly one record with
   `msg == "plugin_notice_queued"`, `levelno == logging.INFO`, `record.plugin_id == "plugin-x"`, `record.kind == "kind-x"`.
3. `_json_default`: `datetime(2026,6,10,12,30,45,tzinfo=UTC)` → `"2026-06-10T12:30:45+00:00"`;
   naive `datetime(2026,6,10,12,0)` → `"2026-06-10T12:00:00"` (note: `str()` would give a space instead of T);
   `date(2026,6,10)` → `"2026-06-10"`; UUID → its str; `Decimal("1.50")` → `"1.50"`; a custom object with `__str__` → that string.
4. `deliver_pending` with fake conn (`fetch = AsyncMock(return_value=rows)`):
   - query contains each of: `"UPDATE plugin_notices"`, `"SET delivered_at = now()"`, `"WHERE tenant_id = $1"`,
     `"AND delivered_at IS NULL"`, `"AND expires_at > now()"`, `"ORDER BY created_at ASC"`, `"LIMIT $2"`,
     `"FOR UPDATE SKIP LOCKED"`, `"RETURNING id, plugin_id, kind, template, payload, created_at"`;
     `conn.fetch.call_args.args[1:] == (tenant, 20)`; with `limit=7` → `(tenant, 7)`.
   - 3 rows → `len(result) == 3`, kinds in row order, each `RenderedNotice` field exact.
   - missing key through delivery: template `"Hi {name}{missing}!"`, payload `{"name": "A"}` → text `"Hi A!"`.
   - payload `'{"a": 1}'` (str) → payload `{"a": 1}`; payload `""` → `{}`; dict payload → same object (`is`).
5. `_render`: `"{a}{b}"` with `{"a": "1", "b": "2"}` → `"12"`; `"{{a}}"` with `{"a": "x"}` → `"{x}"`;
   `"x {missing} y {name}"` with `{"name": "N"}` → `"x  y N"`; two missing occurrences `"{m}{m}"` → `""` and exactly 2
   warning records, each `levelno == logging.WARNING`, `msg == "notice_template_missing_key"`, `record.key == "m"`,
   `record.template == "{m}{m}"`; template of 130 chars with a missing key → `record.template == template[:120]`;
   value `0` → `"0"`, value `False` → `"False"`, value `{"k": 1}` → `"{'k': 1}"`.
6. `RenderedNotice`: `RenderedNotice.__slots__ == ("id", "plugin_id", "kind", "text", "payload", "created_at")`;
   instance has no `__dict__` (`not hasattr(n, "__dict__")`); `to_dict()` exact dict equality for fixed values
   (`created_at=datetime(2026,6,15,10,30,45,tzinfo=UTC)` → `"2026-06-15T10:30:45+00:00"`), and
   `to_dict()["payload"] is n.payload`.

Run `pytest -q -p no:cacheprovider tests/unit/test_memory_list_sql_exact.py tests/unit/test_notice_exact.py -rxX 2>&1 | tail -10`
and paste verbatim. Report any assertion that didn't match actual behaviour with the actual value.
