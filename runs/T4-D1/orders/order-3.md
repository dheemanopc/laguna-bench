# Work order 3 — execute order 2 (nothing was changed last time)

Your previous turn replied "Task completed." without making any change — every item is still open.
Please now actually carry out **every item** of
`~/laguna-bench/runs/T4-D1/orders/order-2.md` (read that file now; it is the full spec):

1. delete the 8 scratch files at the repo root;
2. `mindmap_get.py`: open_loops over the whole map regardless of `since` (no early return with empty
   open_loops), edges fetched over all members and kept when AT LEAST ONE endpoint is returned,
   module-level truncation constant + helper, docstring;
3. `mindmap_resolve.py`: module-level edge-kind constant, delete duplicate `MindmapResolvedEntry`,
   payload `reference_kind=None` when no resolver, docstring;
4. `service.py`: `int(...)` cursor, tenant-scope linter clean;
5. docs: `docs/mindmap-v1-build-design.md` and `skills/mindmap-driver/SKILL.md`;
6. make `tests/integration/test_mindmap_branch_status.py` pass with the scenarios listed;
7. ruff format / ruff check / mypy.

Then report the exact command outputs requested at the bottom of order-2.md (alembic, targeted pytest,
full suite failure lists with and without your change, ruff, mypy, git status). Do not stop until all
seven items are done and verified.
