# Work order 6 — tiny fix (TESTS ONLY)

Your last session stopped before doing anything. Do ONLY this, then stop. Keep tool output short
(use `-q` and `| tail -15`); don't re-read large files you don't need.

In `tests/integration/test_memory_list_pagination_db.py` and `tests/integration/test_memory_list_db.py`:

1. Add `import asyncpg` (with `# type: ignore[import-untyped]` like other files) and replace every
   `raises=Exception` in an xfail marker with `raises=asyncpg.exceptions.DataError`.
2. In `test_full_walk_updated_at`, the expected list is wrong. updated_at hours are m0=3, m1=0, m2=4,
   m3=1, m4=2, so DESC order is `[m2, m0, m4, m3, m1]`. Change the assertion (and the comment) to that.
3. Change each pagination xfail `reason=` to:
   `"BUG: cursor timestamp bound as str to timestamptz param (asyncpg DataError); next_cursor is also the overflow row with a strict keyset predicate, so a row per page would be skipped"`.
4. Add two passing tests to the pagination file (copy the data setup from the existing tests):
   - `test_first_page_updated_at_cursor`: the updated_at data from (2), `MemoryListInput(limit=2, order_by="updated_at")`
     → `[r.id for r in out.results] == [m2, m0]` and
     `_decode_cursor(out.next_cursor) == ((base + timedelta(hours=2)).isoformat(), str(m4))`.
   - `test_first_page_asc_cursor`: m0..m4 with created_at base+i minutes, `MemoryListInput(limit=2, order="asc")`
     → `[m0, m1]` and cursor == `((base + timedelta(minutes=2)).isoformat(), str(m2))`.

Run:
`pytest -q -p no:cacheprovider tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py -rxX 2>&1 | tail -15`
and paste it verbatim. That's the whole report.
