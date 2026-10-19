# Order 3 — Continue order 2 (your previous session was cut off by a timeout)

Your last run of order 2 (`orders/order-2.md` in the parent folder — re-read it if needed; its content is summarised
here) was interrupted. Progress observed on disk: sections A, B (cursor int/dict/bool xfails, plugin_id str), C and most
of D are done in `tests/integration/test_memory_list_behaviour.py` / `tests/unit/test_memory_list_models_cursor.py`.
Still to do — work efficiently, run tests in focused subsets, avoid very long exploratory loops:

1. **Section B remainder**: real-DB test in `test_memory_list_behaviour.py`: a cursor that base64/JSON-decodes cleanly
   but contains a malformed timestamp (`["not-a-date", str(uuid4())]`) and one with a malformed uuid
   (`["2026-01-01T00:00:00+00:00", "nope"]`) → correct behaviour is `JsonRpcError` code `-32602`. Mark strict xfail
   (`reason="BUG: …"`) only if it deterministically fails; report the actual exception.
2. **Section E (notices) — entirely still to do** in `tests/integration/test_plugin_notices_behaviour.py`:
   - TTL exact: `expires_at - created_at == timedelta(seconds=86400)` default, `== timedelta(seconds=60)` custom;
     remove the wall-clock windows. `ttl_seconds=0` → `expires_at == created_at` and never delivered.
   - Default limit: 21 pending with explicit distinct created_at, `deliver_pending(conn, tenant)` with NO limit arg →
     exactly the 20 oldest (exact set), then a second call → exactly the remaining 1.
   - Oldest-first ORDER: stop sorting before comparing. Insert ~6 rows in shuffled physical order with distinct
     created_at; assert the returned list's order equals created_at ascending. Repeat the test ~20 times (shell loop)
     to learn whether current code is deterministic: always ordered → plain passing test; deterministically wrong →
     `xfail(strict=True, reason="BUG: UPDATE … RETURNING does not preserve the subquery ORDER BY; not oldest-first")`;
     nondeterministic → `xfail(strict=False)` with the BUG reason and say so. Keep set-based selection tests passing
     (including the `limit=2` selection test: exact set of the 2 oldest).
   - At-most-once: in the limit case, check in the DB that exactly the delivered ids have `delivered_at IS NOT NULL`
     and the rest `IS NULL`. A row inserted with `delivered_at` already set is never returned.
   - Tenant isolation: after delivering tenant A, tenant B's rows still `delivered_at IS NULL` in DB; then B gets its
     exact set.
   - Missing-key warning: caplog record attributes `record.key == "<key>"` and
     `record.template == template[:120]` for a >120-char template (also `!= template`).
   - Queue → deliver round-trip: payload with tz-aware datetime, naive datetime, date, UUID, nested list/dict; assert
     the exact delivered `payload` dict and exact rendered `text` (e.g. `"due {fire_at} id {item}"`).
   - `to_dict()` of a delivered notice: exact full-dict equality with all six keys.
3. Run and report:
   - `pytest -q -p no:cacheprovider tests/integration/test_memory_list_behaviour.py tests/integration/test_plugin_notices_behaviour.py tests/unit/test_memory_list_models_cursor.py tests/unit/test_notice_render_and_serialize.py` three times (exact summary lines + wall time); `-n 4` too if pytest-xdist is installed.
   - Plus the existing related tests: `tests/unit/test_tools_list.py tests/unit/test_search_preview_lenient.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py`.
   - `ruff check` on the four files.
   - Oldest-first experiment result; every xfail with its concrete observed failure; `git status --short`.
