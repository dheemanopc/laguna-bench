# Work order 12 — make the oldest-first xfail plan-independent (small; no shell loops needed)

(Shell loops/psql aren't available to you — fine, use only single `pytest` commands.)

Problem: `test_oldest_first_with_reverse_insertion` is a strict xfail. On a bigger shared table
the planner can pick a nested-loop/index plan that happens to return rows sorted → XPASS → suite
breaks under mutation testing. Make it deterministic:

1. Insert the three notices in ONE statement, in reverse chronological order (newest first), e.g.
   `INSERT INTO plugin_notices (...) VALUES (...new...), (...mid...), (...old...) RETURNING id, kind`
   (map kind→id from the RETURNING rows), payload `'{}'::jsonb` literal, expires_at now()+1h.
2. Inside the `system_tx(pg_pool)` block, BEFORE calling `deliver_pending(conn, ...)`, run:
   `SET LOCAL enable_nestloop = off`, `SET LOCAL enable_mergejoin = off`,
   `SET LOCAL enable_indexscan = off`, `SET LOCAL enable_bitmapscan = off`
   (comment: the oldest-first contract must hold for any plan; this pins the hash-join/seq-scan
   plan under which RETURNING follows heap order, not the subquery's ORDER BY).
3. Temporarily add `@pytest.mark.parametrize("rep", range(25))` to that test, run
   `pytest -q -p no:cacheprovider tests/integration/test_plugin_notices_db.py -k reverse -rxX 2>&1 | tail -5`
   and paste. Then, if `pytest -n` (xdist) is available, run
   `pytest -q -p no:cacheprovider -n 4 tests/integration/test_plugin_notices_db.py -k reverse 2>&1 | tail -3` and paste.
4. Decision:
   - all 25 (and xdist runs) xfailed → remove the temporary parametrize, keep strict xfail with
     reason `"BUG: deliver_pending relies on UPDATE ... RETURNING order; ORDER BY only in subquery, so result is not oldest-first (heap order under hash join)"`.
   - any XPASS → remove the xfail, rename to `test_reverse_insertion_delivers_all`, assert
     `set(ids) == {old, mid, new}` and `len(ids) == 3`, and add a comment documenting the latent ordering bug.
5. Also run the whole integration set once with xdist if available:
   `pytest -q -p no:cacheprovider -n 4 tests/integration/test_plugin_notices_db.py tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py tests/integration/test_memory_list_filters_db.py 2>&1 | tail -5`
   (if xdist isn't installed, say so and run it twice without -n). Paste.

Report: pasted outputs and which branch of the decision you took.
