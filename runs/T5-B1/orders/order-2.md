# Work order 2 — implementation part (smaller scope; previous run timed out with no changes)

The previous order (`order-1.md`, same directory as this file: ~/laguna-bench/runs/T5-B1/orders/order-1.md)
timed out after 45 minutes with **no file changes**. Please read order-1.md for the full design, but in THIS
order do only sections **A, B, C, D, E** of it plus the unit test file (Tests §1). Do NOT write the integration
concurrency tests yet (a later order will) and do NOT run the full suite yet.

Working rules for this run (important):
- Make edits early and incrementally; don't spend long exploring. The design is already decided in order-1.md.
- Wrap EVERY shell command that could hang in `timeout`, e.g. `timeout 300 pytest -q -p no:cacheprovider tests/unit/test_tools_update.py`,
  `timeout 120 alembic upgrade head`. If something hangs, note it and move on.
- Finish within ~30 minutes and reply with the short report (files changed, commands + results, open issues).

Verification for this order:
- `timeout 120 alembic upgrade head`, then `timeout 120 alembic downgrade -1 && timeout 120 alembic upgrade head`
- `timeout 300 pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_revision.py tests/unit/test_web_memories_handler.py tests/unit/test_embedding_status_select.py tests/unit/test_plugin_memory_client_tier1.py`
- `timeout 300 ruff check src tests`, `timeout 600 mypy`, `timeout 120 python tools/dump_schemas.py --check`
