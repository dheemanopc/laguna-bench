# Work order 4 — RESTORE the reviewed source; it was overwritten

During order 3 (which timed out) the `src/` files were replaced with a different, regressed implementation. The current working tree is NOT the version I reviewed and approved after order 2. Problems in the current tree:
- `_find_current_in_chain` queries `WHERE superseded_by = $1` — it walks the chain **backwards** (finds the predecessor), so `current_id` is wrong.
- If no live row is found, the superseded check falls through and **updates a non-current row** (fork / write to stale row).
- `target["is_current"]`, `target["updated_at"]`, `new_row["updated_at"]` use `[]` — the mock-based tests in `tests/unit/test_tools_update.py` pass rows without these keys → KeyError. Must use `.get()` with defaults (is_current→True).
- `compute_revision` is back to float `dt.timestamp() * 1_000_000` (rounding collisions); signature changed to `str` id.
- `expected_revision` check runs before the superseded check, so a superseded target with a token gets no `current_id`.
- `MemoryUpdateOutput.revision` became required; the explanatory comments/docstring were lost.

## Step 1 — recover the approved version
The approved version is what `git stash push -- src/` stashed at the start of order 3 (and possibly what was there before any later rewrite). Try to recover it:
- `git stash list`; `git fsck --no-reflog --unreachable 2>/dev/null | grep commit` and inspect candidates with `git show <sha> --stat` / `git show <sha>:src/mem_mcp/memory/versioning.py`. The approved `versioning.py` has `compute_revision(memory_id: UUID | None, updated_at: datetime | None)` computing `(ts - datetime(1970, 1, 1, tzinfo=UTC)) // timedelta(microseconds=1)`; approved `update.py` has a module-level `_row_revision`, `_UPDATE_CONFLICT_CODE`, and a module-level `async def _find_current_in_chain(conn, target_id, tenant_id)` using a `WITH RECURSIVE chain` CTE following `superseded_by` forward. Restore those 4 src files from that commit (`git checkout <sha> -- src/...` or `git show > file`).
- If it can't be recovered, re-implement to exactly this spec (it is what was approved):
  - `versioning.compute_revision(memory_id: UUID | None, updated_at: datetime | None) -> str`: sha256 of `f"{id_or_empty}:{exact_integer_epoch_micros_utc_or_empty}"`, first 24 hex chars; naive → UTC.
  - `MemoryRecord.revision: str = ""` + `model_validator(mode="after")` filling it when empty.
  - `MemoryUpdateInput.expected_revision: str | None = None`; `MemoryUpdateOutput.revision: str = ""`.
  - Lookup `SELECT id, type, content, version, tags, metadata, deleted_at, is_current, superseded_by, updated_at ... FOR UPDATE`. Order: not found (-32602) → deleted (-32602) → `if not target.get("is_current", True)`: ALWAYS raise -32000 `update_conflict` with `current_id` (str, found by following `superseded_by` FORWARD via recursive CTE, preferring the current row, else last reachable) and `current_revision` → then stale `expected_revision` (compare to `compute_revision(target.get("id"), target.get("updated_at"))`) → -32000 with `current_revision`. All before quota/embedding. Conflict-path-only extra queries.
  - Versioned path: `RETURNING id, version, updated_at`; old-row UPDATE `... AND is_current = true`; revision from `new_row.get("updated_at")`.
  - In-place: `updated_at = GREATEST(clock_timestamp(), updated_at + interval '1 microsecond')`, `RETURNING updated_at`, revision from that.
  - Tool description: original text verbatim + an added concurrency paragraph (expected_revision, opaque revision output, serialization, -32000/`update_conflict`, `current_revision`, `current_id`, nothing written on refusal, re-read/merge/retry).
- Also make sure the two test files `tests/unit/test_tools_update_concurrency.py` and `tests/integration/test_update_concurrency.py` are consistent with the restored signature (e.g. `compute_revision` called with UUID/None, the µs=999999 boundary unit test exists).

## Step 2 — verify (keep it short; avoid timeouts — use `timeout 600` per pytest run and don't repeat long runs)
1. `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_concurrency.py tests/integration/test_update_concurrency.py` → paste the summary line.
2. Fail-without-fix: `git stash push -- src/`, run `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py -x --no-header -rf 2>&1 | tail -30` (without -x actually — run all, list each failure reason in one line), then **immediately** `git stash pop` and confirm with `git status --short` + `git stash list` (must be empty) that src is restored. Do not do anything else between push and pop.
3. Full suite with changes: `timeout 900 pytest -q -p no:cacheprovider tests/unit tests/integration 2>&1 | grep -E "^(FAILED|ERROR)|passed|failed"`. Report the FAILED/ERROR list. For baseline, check whether each listed failure is unrelated to memory_update/get (e.g. team/role fixture issues); if any failure touches update/get/MemoryRecord/versioning, investigate.
4. `ruff check src tests` and `mypy`.
Report: how you restored (commit sha or re-implemented), and the exact outputs.
