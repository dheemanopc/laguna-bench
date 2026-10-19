# Order 2 — Revert source change; close coverage gaps; tighten weak tests

## 1. REVERT the source change (mandatory, first)
Source changes are disqualifying for this task — tests only. Run
`git checkout -- src/mem_mcp/plugins/notice_delivery.py` and confirm `git status` shows **only** the
four new test files. Never touch `src/` again.

The ordering problem you found is a real bug — document it with tests instead:
- `UPDATE ... WHERE id IN (subquery ORDER BY ... LIMIT) RETURNING` does not guarantee the RETURNING
  order, so `deliver_pending` may not return oldest-first.
- Write a deterministic test asserting the **set** of claimed notices under a limit is the oldest N
  (e.g. 3 notices with explicit created_at spaced by hours, inserted in newest-first physical order,
  `limit=2` → exactly the two oldest ids are returned and marked delivered; the newest stays
  `delivered_at IS NULL`). That should pass today.
- Write a separate test asserting the returned **list order** is oldest-first, marked
  `@pytest.mark.xfail(strict=True, reason="BUG: deliver_pending relies on UPDATE...RETURNING order, which Postgres does not guarantee; notices are not returned oldest-first")`
  — ONLY if, on the unmodified source, it fails deterministically: run it 20+ times
  (e.g. `pytest --count` if pytest-repeat exists, or a shell loop) and in parallel with xdist if
  available. Construct the data so the failure is deterministic (e.g. physical insertion order is the
  reverse of created_at order, ≥5 rows). If you cannot make it fail deterministically, do NOT use strict
  xfail; instead tell me in the report exactly what you observed.

## 2. Fix weak tests
- `test_respects_limit`: must assert `len == 20` exactly, and add a test calling `deliver_pending(conn, tenant_id)`
  **without** `limit` with 21+ pending → exactly 20 returned, and the remainder is delivered on the next call.
- Grep your new files for any `<=`, `>=`, `is not None`, `len(...) > 0`, "or less" style loose assertions and
  replace them with exact values wherever behaviour is deterministic.

## 3. Reconsider cursor xfails in the unit file
`_decode_cursor` only decodes; it's not a bug that it doesn't validate timestamp/uuid or reject extra
elements by itself. Remove these strict xfails: `test_base64_json_array_extra_element`,
`test_base64_bad_timestamp`, `test_base64_bad_uuid` (at the `_decode_cursor` level). Keep object/number ones
only if you reframe them at the **tool** level (below). The contract is at the tool level: an invalid
cursor passed to `MemoryListTool` must raise `JsonRpcError` code `-32602`, message `"invalid cursor"`.

## 4. Missing DB-backed memory_list coverage (add to `tests/integration/test_memory_list_behaviour.py`)
Order 1 asked for these and they're absent. All with real Postgres, exact id sets / exact orders:
- **Pagination walk** (most important): ≥7 memories with distinct created_at (and distinct updated_at
  in a different order), limit=3. Follow `next_cursor` until None. Assert concatenated ids == full
  expected order with no duplicates and **no skipped rows**. Do this for: created_at desc, created_at asc,
  updated_at desc, updated_at asc. Also with a filter active (e.g. tags) while paging.
  If paging with a cursor crashes or skips rows on current source, those are bugs: write the correct-behaviour
  test with `xfail(strict=True, reason="BUG: ...")` stating the exact cause (e.g. next_cursor built from the
  overflow row while predicate is strict → one row skipped per page; or cursor value passed as str
  to a timestamptz param → asyncpg DataError). Also add a passing test pinning what *currently* happens
  where it's deterministic and useful (e.g. first page contents and next_cursor decoding to the
  (limit+1)th row's (created_at iso, id)), so mutants in cursor code still get killed.
- **Ties**: ≥4 memories with identical created_at; page with limit=1/2 in desc and asc; assert full coverage
  with no dupes/skips (xfail strict with reason if broken; confirm determinism).
- **Invalid cursors at the tool level** (real DB): garbage non-base64, base64 non-JSON, base64 `[]`,
  base64 `["x"]`, base64 `{"a":1}`, base64 `5`, base64 `["not-a-date","<uuid4>"]`,
  base64 `["2025-01-01T00:00:00+00:00","not-a-uuid"]`. Correct behaviour: `JsonRpcError` with `.code == -32602`,
  message `"invalid cursor"`, data `{"errors":[{"path":"cursor", ...}]}`. Use passing tests for cases that work,
  strict xfail with exact reason for cases that raise something else (say what is actually raised).
- `type` filter (exact set), `indexable=True` and `indexable=False` (exact sets), `parent_id` (exact set),
  `include_expired` (past-expiry excluded by default; future and NULL included; with flag all included),
  `include_history` (is_current=false excluded by default; included with flag), `include_deleted` combined.
- **team_id per contract**: description says `team_id` accepts a UUID **or team name**, and `"*"` for
  cross-team. Test via the tool's input validation path the project uses (check how other tests invoke tools
  through the input model / dispatcher; `MemoryListInput.model_validate({"team_id": "<name>"})` and `"*"`).
  If rejected, strict xfail with reason "BUG: description promises team name / '*' but input model only accepts UUID".
- Keywords: exact `preview` string for a known short content (e.g. content "Postgres tuning guide",
  keywords "postgres" → assert the exact preview incl. `**Postgres**` markers — determine exact output and pin it);
  keywords + order preserved (asc and desc exact order); keyword with no matches → `[]`.
- Content truncation: content of 2500 chars → returned content == content[:2000] exactly; preview without
  keywords == content[:PREVIEW_FALLBACK_CHARS] exactly.
- Audit on real DB: recorded `details` exact dict for one paged call (`has_next` True) and one final call.

## 5. Notices extras (if missing)
- `_render`: repeated key, non-string values (int, None, list) via `str()`, template >120 chars missing key
  → warning record's `template` extra is exactly `template[:120]`, `key` extra exact; `{}`/`{1a}`/`{ a }`
  untouched; `{{a}}` behaviour pinned.
- `queue` log record: message `plugin_notice_queued`, `plugin_id`, `kind` attributes exact.
- `ttl_seconds`: assert `expires_at - created_at == timedelta(seconds=ttl)` exactly (both from now() in same
  statement) for default and a custom value (e.g. 90). Check the plugin_notices schema for created_at default.
- `RenderedNotice.to_dict()` exact dict equality.

## Acceptance
- `git status` shows only the 4 new test files (no src changes).
- `pytest -q -p no:cacheprovider tests/unit/test_tools_list.py tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py <4 new files>` green; report exact counts (passed/xfailed).
- Run the 4 new files 5 times in a row (and with `-n 4` if xdist available) — report all results; no flakiness.
- `ruff check tests` clean for the new files; `mypy` result reported.
- Report every strict-xfail bug with a one-line explanation and what exception/behaviour actually occurs today.
