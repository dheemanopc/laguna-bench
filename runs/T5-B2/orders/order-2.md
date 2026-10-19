# Work order 2 — fixes after review of order 1

Good work on the core implementation. Please fix the following. Don't modify pre-existing tests.

## Source fixes
1. `compute_revision` (`memory/versioning.py`): `int(ts.timestamp())` goes through a float and can round up near a second boundary (µs=999999), making two different timestamps collide. Compute epoch micros exactly with integer arithmetic, e.g. `(ts - datetime(1970, 1, 1, tzinfo=UTC)) // timedelta(microseconds=1)`. Add a unit test with `microsecond=999999` vs the next second's `microsecond=999999` (they must differ) and the exact expected micro value.
2. Fix the typo "Opague" in `get.py`.
3. Tool description (`mcp/tool_descriptions.py`, `memory_update`): you rewrote the existing guidance. Restore the original first paragraph, "Call when" paragraph and "Do not call for decision or fact types ... use memory_supersede instead (it preserves history)" sentence verbatim, and only *add* the new concurrency text (expected_revision, revision output, serialized concurrent updates, conflict contract: -32000, `data.code="update_conflict"`, `current_revision` for stale tokens, `current_id` (+`current_revision`) when the target was superseded — e.g. by a versioned content update or a note→decision promotion — re-read/merge/retry, nothing written on refusal). Don't describe the token's internal derivation ("id + updated_at") — just call it opaque.

## Missing integration tests (`tests/integration/test_update_concurrency.py`)
Add (each must fail on the original code):
a. **Concurrent versioned fork**: 6 concurrent `memory_update(content=f"v-{i}")` on one current `decision` (no expected_revision). Assert: exactly 1 success with `version == 2` and `is_new_version`; 5 refused with -32000, `data["code"] == "update_conflict"`, `data["current_id"] == str(winner.id)`. In the DB: exactly one row with `supersedes = original_id`, exactly one `is_current = true` row among {original + its successors}, and the original row has `is_current = false, superseded_by = winner.id`.
b. **Type promotion then stale update**: note → `type="decision"` (new row), then update the old note id (e.g. tags add) → refused with `current_id` == the promoted row id; assert memory count for the tenant unchanged by the refused call and the old row's tags unchanged.
c. **Versioned path revision**: after a decision content update, `output.revision == memory_get(output.id).memory.revision`, and differs from the original's revision.
d. **8 concurrent distinct `tags_op="remove"`** on a note with 8 tags (+1 keeper tag) → only the keeper remains.
e. **Concurrent stale token**: use a revision that is truly stale (do one update first, then fire 6 concurrent updates with the old token) → all 6 refused with `current_revision` == the post-update revision, content unchanged. (The existing `test_6_concurrent_stale_expected_revision` actually uses a valid token — rename/redocument it accordingly or leave it, but make sure in the same-valid-token test you also assert each refusal's `data["code"] == "update_conflict"` and `data["current_revision"] == winner.revision`, and that the final DB content equals the winner's content.)
f. Strengthen the sequential superseded-decision test to assert nothing was written (row count unchanged, v1 row unchanged).
g. Widen race windows: make the stub embedder `await asyncio.sleep(0.02)` before returning (in-place content updates and versioned path both embed while holding the lock — that's fine).
h. `memory_get` fires a background access bump (`bump_access`). Before `pool.close()` in the fixture, let it drain (check `mem_mcp/memory/access_tracking.py` for how it schedules — await pending tasks or a short sleep, whichever matches how other integration tests handle it). Ensure no "pool is closing" warnings/errors.

## Verification (report exact output)
1. `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_concurrency.py tests/integration/test_update_concurrency.py` — all pass. Run the integration file 3 times to check for flakiness.
2. **Prove the new integration tests fail without the fix**: `git stash push src/` (stash only src changes), run `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` and report which tests fail and why (attribute/field errors for `revision`/`expected_revision` are expected for revision tests; the tags/fork tests must fail on assertions about lost tags / multiple current rows). Then `git stash pop` and confirm `git status` shows your changes restored.
3. Full suite: `pytest -q -p no:cacheprovider tests/unit tests/integration` with your changes, and the same with `src/` stashed (baseline). Report the list of failing/erroring test node ids for both and confirm the "with changes" set ⊆ baseline set (excluding your new test files).
4. `ruff check src tests` and `mypy` clean.
