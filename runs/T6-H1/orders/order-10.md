# Work order 10 — plugin notices DB tests (TESTS ONLY, small)

Keep output short. Edit only `tests/integration/test_plugin_notices_db.py` (your own new file).
Helper for direct inserts: write `_insert_notice(pool, tenant, *, kind, template="t", payload="{}",
created_at, expires_at, delivered_at=None) -> UUID` using `INSERT ... RETURNING id` (pass payload
as a dict if the codec double-encodes strings — check what works and keeps `jsonb_typeof = 'object'`).

1. TTL exact: replace the `abs(diff - ttl) < 1` check with
   `row["expires_at"] - row["created_at"] == timedelta(seconds=3600)`. Add
   `test_queue_default_ttl_exact` (call `queue("k","t",{})` with no ttl kwarg → `== timedelta(seconds=86400)`)
   and `test_queue_small_ttl_exact` (ttl_seconds=1 → `timedelta(seconds=1)`). If created_at isn't the same
   `now()` as expires_at (column default vs statement), report what you see instead of loosening.
2. `test_datetime_payload_round_trip_through_delivery` (must PASS; regression for "notices crashed on
   datetime payloads"): `dt = datetime(2026,6,15,10,30,tzinfo=UTC)`, `d = date(2026,6,15)`,
   `u = UUID("12345678-1234-5678-1234-567812345678")`;
   `queue("reminder.due", "Due {fire_at} on {day} ({item_id})", {"fire_at": dt, "day": d, "item_id": u})`;
   deliver inside `system_tx` → exactly 1 notice with
   `payload == {"fire_at": "2026-06-15T10:30:00+00:00", "day": "2026-06-15", "item_id": "12345678-1234-5678-1234-567812345678"}`
   and `text == "Due 2026-06-15T10:30:00+00:00 on 2026-06-15 (12345678-1234-5678-1234-567812345678)"`,
   `kind == "reminder.due"`, `plugin_id` == the client's plugin id.
3. Oldest-first with REVERSE insertion: insert n_new (created_at = now-1h), then n_mid (now-2h), then
   n_old (now-3h), all expires_at = now+1h. deliver(limit=10) → ids `[n_old, n_mid, n_new]`.
   Run the test 20 times (`pytest ... -k reverse --count` isn't available; just loop in shell
   `for i in $(seq 20); do pytest -q -p no:cacheprovider <file> -k reverse | tail -1; done`).
   If it passes 20/20, keep it passing. If it fails deterministically (20/20), mark
   `xfail(strict=True, reason="BUG: UPDATE...RETURNING order not guaranteed; deliver_pending not oldest-first")`.
   If it's flaky, tell me the ratio and DON'T keep a strict xfail (sort-agnostic assertion + note).
4. `test_limit_takes_oldest_then_rest`: 5 notices created_at now-5h..now-1h (o1 oldest … o5).
   `limit=3` → ids (as a set AND, if item 3 passed, as a list) `[o1, o2, o3]`; second call (default limit)
   → `[o4, o5]`; third → `[]`.
5. `test_default_limit_is_20`: 21 notices with distinct created_at (now - (21-i) minutes). First call with
   no limit arg → 20 notices, ids == the 20 oldest (set equality); second → exactly the newest one.
6. `test_at_most_once_marks_exactly_delivered`: 3 pending; deliver(limit=2) → 2 ids; DB check:
   `delivered_at IS NOT NULL` exactly for those 2 ids, NULL for the 3rd; second deliver → only the 3rd id.
7. `test_already_delivered_and_expired_skipped`: rows: delivered (delivered_at=now-1m, expires future),
   expired (expires_at now-1s, undelivered), ok (undelivered, future) → deliver → `[ok]` only; the
   expired row's `delivered_at` stays NULL.
8. Tenant isolation: tighten the existing test — assert exact ids for A, and that B's row still
   has delivered_at NULL after A's delivery, then B gets exactly its id.
9. `test_missing_placeholder_renders_empty`: queue template `"Hi {name}, {missing}!"` payload
   `{"name": "Ann"}` → text `"Hi Ann, !"`.
10. `to_dict` exact: after delivering one notice, read the row's id/created_at from the table and
    assert `notice.to_dict() == {"id": str(row_id), "plugin_id": "reminders", "kind": "reminder_fired",
    "text": "<rendered>", "payload": {...}, "created_at": row_created_at.isoformat()}`.
11. The two existing jsonb xfails: confirm with a one-line note each why they fail now (paste the
    assertion error). `test_queue_datetime_uuid_date_serialization` asserts on the raw row — fine to keep
    as xfail (raw row is a str, not dict), but make it `raises=TypeError` or `AssertionError`, whichever is
    observed, instead of no `raises`.

Run `pytest -q -p no:cacheprovider tests/integration/test_plugin_notices_db.py -rxX 2>&1 | tail -15`, paste
verbatim, plus the 20-run result for item 3.
