# Work order 11 — determinism check for the oldest-first xfail (small)

`test_oldest_first_with_reverse_insertion` is a strict xfail. If it ever passes (XPASS) it breaks
the suite. Mutation testing runs it hundreds of times in parallel on a shared DB, where the heap
layout (free space from deleted rows) and the query plan can change. I need evidence.

1. Paste the plan: inside a test-like script or psql, run
   `EXPLAIN UPDATE plugin_notices SET delivered_at = now() WHERE id IN (SELECT id FROM plugin_notices WHERE tenant_id = '<some uuid>' AND delivered_at IS NULL AND expires_at > now() ORDER BY created_at ASC LIMIT 20 FOR UPDATE SKIP LOCKED) RETURNING id;`
   against the test DB (`MEM_MCP_TEST_DSN`, e.g. via `psql "$MEM_MCP_TEST_DSN"` or a tiny python
   asyncpg one-liner). Paste output.
2. Sequential: `for i in $(seq 30); do pytest -q -p no:cacheprovider tests/integration/test_plugin_notices_db.py -k reverse 2>&1 | tail -1; done | sort | uniq -c`
3. Concurrent: run 4 copies of the WHOLE integration test set in parallel, 5 rounds:
   `for r in $(seq 5); do for j in 1 2 3 4; do (pytest -q -p no:cacheprovider tests/integration/test_plugin_notices_db.py tests/integration/test_memory_list_db.py tests/integration/test_memory_list_pagination_db.py tests/integration/test_memory_list_filters_db.py 2>&1 | tail -1) & done; wait; done | sort | uniq -c`
4. Paste both `uniq -c` outputs.

Decision rule:
- If every run shows the reverse test as xfailed (no XPASS / no "failed"), keep it as is.
- If ANY run XPASSes, remove the xfail marker from that test and instead make it a passing test that
  only asserts the delivered ids as a SET (`set(ids) == {n_old, n_mid, n_new}`) plus `len(ids) == 3`,
  and rename it `test_reverse_insertion_delivers_all`. Add a comment that the order is not guaranteed
  by `UPDATE ... RETURNING` (latent bug, not deterministic).
- Also report any other failure seen in the concurrent runs (with the test id and error) — those are
  isolation bugs in our tests that must be fixed. Fix them if any.

Paste the final `pytest -q -p no:cacheprovider tests/integration/test_plugin_notices_db.py -rxX | tail -8`.
