# Work order 3 — integration concurrency tests + full verification

Implementation from order 2 looks good. Remaining work:

1. **Remove the stray `_schema_check_tmp.py`** from the repo root (also unstage it: `git rm --cached -f _schema_check_tmp.py` / delete the file).
   If you can't run `python` directly, `python -m`/`pytest` may still work; don't leave helper files in the repo.
   (If you need a schema drift check, do it from a throwaway test under the scratch/tmp dir, not in the repo.)

2. **Write `tests/integration/test_update_concurrency.py`** — exactly as specified in order-1.md "Tests to add §2"
   (~/laguna-bench/runs/T5-B1/orders/order-1.md). Summary:
   - Fixture like `tests/integration/test_mindmap_e2e.py` (tenant + team + primary identity with `default_team_id`),
     memories created via `MemoryWriteTool` + stub embedder (stub can `await asyncio.sleep(0.05)` to widen the race).
   - Own asyncpg pool with `max_size>=10` built the same way as the project's pool/conftest fixture (same init/codecs),
     closed at the end after letting `memory_get`'s background access bump drain.
   - Each concurrency test: `asyncio.gather(..., return_exceptions=True)` with ≥8 calls.
     a) concurrent `tags_op="add"` distinct tags on a `position`/`note` → all present; b) concurrent `remove` → all removed;
     c) concurrent content updates of one `decision` → exactly 1 success, others `JsonRpcError` code -32000,
        `data["code"]=="update_conflict"`, `data["current_id"]` == winner's new id; DB has exactly one `is_current` row in the chain
        and exactly one row with `supersedes = original id`;
     d) concurrent updates with the same valid `expected_revision` → exactly 1 success, others conflict with `current_revision`
        equal to the winner's output revision;
     e) sequential: update decision v1 after v2 exists → conflict with `current_id`=v2; note→decision promotion, then update old
        note id → conflict with `current_id`=new id; stale expected_revision sequential → conflict, row unchanged;
     f) revision semantics: changes on each update (content in-place, tags-only, no-op), `memory_update(...).revision ==
        memory_get(...).memory.revision` on both paths (versioned: for the new id); revision unchanged after a `memory_get`
        (wait for its access bump, then get again); history records have non-empty revisions.
   - Every test must clean up after itself in the same way existing integration tests do.

3. **Prove the tests catch the bug**: temporarily remove `FOR UPDATE` (and the `is_current` check) from update.py, run the
   concurrency file, record which tests fail, then restore the file exactly (`git diff` must show only the intended change afterwards).

4. **Verify and report exact results** (wrap commands in `timeout`):
   - `timeout 120 alembic upgrade head`; `timeout 120 alembic downgrade -1 && timeout 120 alembic upgrade head`
   - `timeout 300 pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` — run it 5 times in a row
   - `timeout 900 pytest -q -p no:cacheprovider` (full suite). For every failure, state whether it is pre-existing: verify by
     checking whether it also fails with your changes stashed (`git stash -u`, rerun only those failing tests, `git stash pop`;
     note the DB has the 0046 column — that's fine for pre-existence checks). Paste the summary line.
   - `timeout 300 ruff check src tests`, `timeout 600 mypy`
