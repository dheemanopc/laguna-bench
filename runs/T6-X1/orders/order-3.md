# Order 3 — Proceed with ALL of Order 2 (yes, do it all)

1. `src/mem_mcp/plugins/notice_delivery.py` must be byte-identical to HEAD. Run exactly:
   `git checkout HEAD -- src/mem_mcp/plugins/notice_delivery.py` and confirm `git diff --stat` is empty
   (only the 4 untracked test files remain in `git status`). Do not hand-edit src files.

2. Then implement **every item in sections 1–5 of `~/laguna-bench/runs/T6-X1/orders/order-2.md`**
   (re-read it). This is the core of the task, not optional extra scope: the DB-backed pagination walk,
   tie-breaking, tool-level invalid cursors, type/indexable/parent_id/include_expired/include_history,
   team_id contract, exact preview strings, truncation, audit on real DB, the deliver_pending ordering bug test
   (set-of-oldest-N passing test + strict xfail for return order only if deterministic), default-limit test,
   tightening loose assertions, removing the three `_decode_cursor`-level xfails, and the notices extras.

3. Acceptance is the same as Order 2. In the report, list for each strict xfail: test name, reason, and the
   exact exception/behaviour observed today, plus the repeated-run (5×, and xdist if available) results.
