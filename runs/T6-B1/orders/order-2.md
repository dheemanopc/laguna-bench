# Order 2 — finish, tighten and VERIFY the new test suite

Your previous session ran out of time before reporting. **Work efficiently: run tests early, keep edits targeted, and finish with the report.** Still tests only — no changes under `src/`, existing tests, conftest, pyproject.

## 1. Housekeeping
- Delete the stray `_env_check.sh` and `_run_test.sh` from the repo root.

## 2. Remove spurious "bugs" (they are not contract violations)
- `_render` turning a `None` value into `"None"`: the contract only says *missing* keys render empty. Delete the xfail tests `test_none_payload_value_renders_empty` (integration) and `test_none_value_renders_empty` (unit) and keep the passing tests that pin the current `"None"` behaviour. Remove "BUG f" from the module docstrings.
- `to_dict()` returning payload by reference: not a bug. Delete both `test_to_dict_returns_payload_copy` xfails; instead add a passing assertion `rn.to_dict()["payload"] is rn.payload`? — no, just assert equality `== payload`. Remove "BUG g" text.
- `test_sql_lacks_timestamptz_cast_on_cursor_param` / `test_cursor_value_is_str_not_datetime`: if multi-page pagination actually works against the real DB (it appears to), this is not a bug — keep them only as plain passing tests that pin params (no "BUG" wording), or delete them. Report what you found.

## 3. Strengthen pagination (exact pages)
Replace the weak `assert len(page2.results) >= 1` with exact assertions of current behaviour. With 5 rows (row 0..row 4, distinct created_at), limit=2:
- add a passing test `test_pagination_pages_current_behaviour` that walks pages for **each** of: (desc, created_at), (asc, created_at), (desc, updated_at), (asc, updated_at — give updated_at an order different from created_at). Assert the exact content list of every page and that the final `next_cursor is None`, and that each `next_cursor` decodes (via `_decode_cursor`) to `(row.created_at/updated_at .isoformat(), str(row.id))` of the exact row it was built from. Whatever the current behaviour is (e.g. desc pages `[4,3]`, `[1,0]` due to the overflow-row cursor) — pin it exactly.
- Keep the strict-xfail `test_pagination_round_trip_no_rows_skipped` (BUG h) and make it assert the exact ordered concatenation == all 5 rows in order.
- **Ties (suspected BUG c)**: insert ≥4 rows with *identical* created_at; ORDER BY is `created_at DESC, id` (id ascending) but the keyset predicate is `(created_at, id) < (...)`. Walk with limit=1 and limit=2 in desc and asc. Determine exactly what happens and report it. If correct behaviour (every row exactly once, in the same order as one big unpaginated page) fails deterministically, add a strict xfail "BUG(c)". Note ids are random UUIDs, so make the test deterministic: either insert rows with explicit fixed ids chosen so the outcome is deterministic, or assert a property that fails for every id ordering. Verify by running it ≥5 times.

## 4. Missing coverage from order 1 (add these; exact assertions)
memory_list (integration):
- **content truncation**: 2500-char content → `content == full[:2000]`; a 1999/2000-char content unchanged.
- **preview without keywords**: content of 400 chars → `preview == content[:280]`; short content → preview == content.
- **preview with keywords**: short content e.g. `"I love postgres databases"`, keywords `"postgres"` → assert the preview contains `"**postgres**"` (assert the exact string if it's deterministic); long content (>8000 chars) whose only match is beyond char 8000 → preview falls back to `content[:280]`; preview length ≤ 600 for a long multi-match content (and check it's actually > 280 or otherwise distinguishes the 600 cap if you can construct such a case).
- **keywords**: OR semantics across two words, stemming (`"running"` matches content `"he runs daily"`), all-stopword `"the and"` → `[]`, ordering preserved (desc created_at) under a keyword filter, combined with tags filter.
- **tags**: exact id sets for `[a]`, `[a,b]`, `[a,b,c]`, `[]`(no filter → all), a tag nobody has → `[]`.
- **since/until** boundary inclusivity (exact timestamps equal to a row's created_at are included) and combined window.
- **indexable** True and False both; **team_id** with a second team in the same tenant (row in team2 excluded when filtering team1, and vice versa); **parent_id** exact set.
- include_* flags: assert exact id sets for default vs True; future `expires_at` always included.
- **tenant isolation**: second tenant's rows never appear (exact set).
- **audit `filters_count`**: with the spy, assert exact `details` dicts for: defaults (3), each include_* flag True (2), all three True (0), type+tags+since+until+team_id+indexable+parent_id+keywords (3+8=11), cursor present (+1). Also `has_next` True/False and `result_count`, and `tenant_id/identity_id/client_id/request_id` equal the ctx values, `action == "memory.list"`, `result == "success"`, exactly one audit call per list.
- `output.request_id == ctx.request_id`.
- invalid cursor via the tool (no DB needed beyond ctx): assert `exc.code == -32602`, `exc.message == "invalid cursor"`, and `exc.data == {"errors": [{"path": "cursor", "message": <exact str of the ValueError>}]}` with message starting `"Invalid cursor format: "`. Check what attribute names `JsonRpcError` uses.
- A decodable cursor with a non-timestamp/non-uuid (`["not-a-date","nope"]`): what happens? If it isn't -32602, add a strict xfail BUG (part of d) asserting -32602.

notices (integration):
- queue a payload with tz-aware datetime, naive datetime, `date`, `UUID`, nested list/dict → read raw `payload` from `plugin_notices` and assert exact JSON values (`isoformat()` strings, `str(uuid)`); deliver → `payload` dict equals the same and `text` from template `"due {when} on {day} id {item}"` exact.
- default TTL: `expires_at - created_at == 86400 s` (±2 s); custom `ttl_seconds=120` (±2 s). Exact row fields tenant_id/plugin_id/kind/template.
- default `limit` 20: insert 21 → 20 delivered, the 21st (newest) remains pending and is delivered by the next call.
- oldest-first with ≥6 rows, explicit distinct created_at inserted in shuffled order; assert exact order. Run it ≥10 times (loop in a quick ad-hoc run) to confirm deterministic; report.
- `delivered_at` IS NOT NULL in DB after delivery; expired rows still have `delivered_at IS NULL` after delivery; tenant B rows untouched.
- `isinstance(payload, str)` path: unit test with a fake conn whose `fetch` returns rows with `payload` as a JSON string (→ parsed dict) and as `""` (→ `{}`); assert the exact SQL params passed (`tenant_id`, `limit`) to `fetch`.
- `RenderedNotice.to_dict()` exact dict equality for a full example.

## 5. Verification (report exact output lines)
- `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py tests/unit/test_memory_list_models_cursor.py tests/unit/test_notice_render_and_dict.py tests/integration/test_memory_list_behaviour.py tests/integration/test_plugin_notices_behaviour.py` — run 3×, all pass/xfail, no XPASS. Report wall time.
- If pytest-xdist is installed, also run once with `-n 4`.
- `ruff check tests/unit/test_memory_list_models_cursor.py tests/unit/test_notice_render_and_dict.py tests/integration/test_memory_list_behaviour.py tests/integration/test_plugin_notices_behaviour.py` clean.
- `git status` shows only the 4 new test files.

## Report
Files, test counts (passed/xfailed), the final list of xfail bugs with one-line evidence each, and what happened for the ties (c) and the non-date cursor investigations.
