# Work order 1 — No lost updates on `memory_update` (revision tokens + row locking)

Read `CLAUDE.md` and `CONVENTIONS.md` first. Relevant code: `src/mem_mcp/mcp/tools/update.py`,
`src/mem_mcp/mcp/tools/get.py` (`MemoryRecord`), `src/mem_mcp/memory/versioning.py`,
`src/mem_mcp/mcp/tool_descriptions.py`, `src/mem_mcp/db/tenant_tx.py`.

## Problem
Concurrent `memory_update` calls lose data: (1) concurrent `tags_op="add"/"remove"` merge in Python
against a stale row, so one edit is lost; (2) two concurrent content updates of a `decision` (versioned)
both create version 2 → two current rows superseding the same parent; same fork happens sequentially if a
caller updates an id that is already superseded; (3) no optimistic-concurrency token, so blind overwrites.
Correctness must come from the DB (row locks / conditional writes), NOT in-process locks (multi-worker).

## Required design (please follow)

### 1. Migration: `revision` column
New Alembic migration `alembic/versions/0046_2026_10_16_memory_revision.py` (check the actual current head's
`revision` string and chain `down_revision` to it; follow the existing file style, docstring explaining why):
- `ALTER TABLE memories ADD COLUMN revision uuid NOT NULL DEFAULT gen_random_uuid()` (existing rows get
  random values; new inserts get one by default). Downgrade drops it.
- Check whether mem_app needs any grant (column-level grants?) — look at how other column additions to
  `memories` were done and follow them.
- Apply with `alembic upgrade head`.
Before choosing this, grep for code that would break from a new column on `memories`
(e.g. `SELECT *` from memories fed into `extra="forbid"` models, or `INSERT ... SELECT *`). Report anything found.

Do NOT use `xmin` or `updated_at` as the revision: `memory_get` fires a background access-count bump that
updates the row, which would change xmin; updated_at is not guaranteed unique.

### 2. `memory_update` (update.py)
- Input: add `expected_revision: str | None = None`.
- Output: add `revision: str` — revision of the row that now holds the memory (on the versioned path, the
  NEW row's revision; must equal `memory_get(new_id).memory.revision`).
- Initial lookup becomes `SELECT id, type, content, version, tags, metadata, deleted_at, is_current,
  superseded_by, revision FROM memories WHERE id=$1 AND tenant_id=$2 FOR UPDATE`. With READ COMMITTED, a
  concurrent waiter re-reads the committed row after the lock is released, so tag merges see the latest tags,
  and a superseded row shows `is_current=false`.
- After the existing not-found (-32602) / deleted (-32602) checks (keep them unchanged), in this order:
  a. If the row is not current (`is_current` is false, or `superseded_by` is not null) → refuse with
     `JsonRpcError(-32000, "memory has been superseded", data={"code": "update_conflict",
     "current_id": "<str id of the current row of the chain>", "current_revision": <that row's revision str,
     if found>})`. Resolve the current id by following `superseded_by` forward (recursive CTE, tenant-scoped,
     `WHERE tenant_id = $n`) to the row with no successor / is_current true. Put this chain-resolution SQL in a
     helper in `src/mem_mcp/memory/versioning.py` (domain module taking an asyncpg connection).
  b. If `expected_revision is not None` and `expected_revision != str(target revision)` → refuse with
     `JsonRpcError(-32000, "revision mismatch", data={"code": "update_conflict",
     "current_revision": str(target revision)})`.
  Nothing must be written on refusal (no audit row of success, no quota increment — raising inside the tx rolls
  back anyway; just make sure the raise happens before any writes/embedding).
- Every successful write sets a fresh revision: in-place UPDATEs add `revision = gen_random_uuid()` and
  `RETURNING revision`; the versioned INSERT uses `RETURNING id, version, revision` (default generates it).
  Also set a new revision on the old row when marking it superseded (harmless, signals change).
  Additionally guard the supersede UPDATE with `AND is_current` (defence in depth) and if it affects 0 rows,
  raise the conflict (rolls back the insert).
- Even a no-op update (e.g. same tags) must yield a new revision — two successive successful updates never
  return the same revision.
- **Mock compatibility:** the existing unit tests in `tests/unit/test_tools_update.py` use an `AsyncMock` conn
  whose `fetchrow` returns a plain dict lacking `is_current`, `superseded_by`, `revision`, `version`, and whose
  `fetchval` returns a datetime. They must keep passing UNMODIFIED. So read new keys tolerantly
  (`target.get("is_current", True)`, `target.get("superseded_by")`, etc.), and convert whatever you get back for
  revision with `str(...)` (fall back sensibly if missing). Read those tests fully before coding.
- Ensure the type-promotion path (note → decision) also goes through the same lock/current checks, so a later
  update of the old note id is refused with `current_id` of the decision.

### 3. `MemoryRecord` (get.py)
- Add `revision: str` field that is NOT required: if absent/None at construction, a `model_validator(mode="before")`
  (or similar) fills a deterministic non-empty string derived from existing fields (e.g. `f"{id}:{version}:{updated_at.isoformat()}"`).
  It must appear in `model_dump()`. If a UUID is passed, coerce to `str`.
- Add `revision` to both SELECTs in `memory_get` (main row + history CTE, both arms) so the real DB revision is
  returned. Check other places that build `MemoryRecord` (grep) — they must still work; add `revision` to their
  SELECT where it's cheap.

### 4. Tool description
Update `TOOL_DESCRIPTIONS["memory_update"]` in house style: document `expected_revision` (take `memory.revision`
from memory_get, pass it back to apply only if unchanged), the output `revision`, and the conflict contract
(-32000, `data.code="update_conflict"`, `current_revision` for stale token → re-read, merge, retry;
`current_id` when target was superseded → update the current version instead). Note concurrent tag add/remove
are merged safely.

### 5. Constraints
- Do not change the plugin SDK `MemoryClient.update` signature (`src/mem_mcp/plugins/clients/memory.py`); check
  web callers of the update tool/output still work.
- Do not modify existing tests.

## Tests to add (new file, e.g. `tests/integration/test_memory_update_concurrency.py`)
Real Postgres. Build fixture like `tests/integration/test_mindmap_e2e.py` (tenant + team + primary identity with
`default_team_id`, oauth client; UUID-suffixed names). Create your OWN `asyncpg` pool with e.g. `max_size=12`
(the default `pg_pool` fixture has only 4) using the same DSN/init as the conftest pool; close it at the end
(let `memory_get`'s background access bump drain first). Create memories with `MemoryWriteTool` + stub embedder.
Each concurrent call gets its own ToolContext; use `asyncio.gather(..., return_exceptions=True)`.
Cover at least:
1. 8 concurrent `tags_op="add"` with distinct tags on one note → all 8 tags present afterwards.
2. Concurrent `tags_op="remove"` of distinct tags → all removed.
3. 6 concurrent content updates on one current `decision` → exactly 1 success (version 2), 5 refused with
   -32000/update_conflict and `current_id` == the winner's id; DB has exactly one `is_current` row in the chain.
4. Sequential: update decision (v2), then update the old v1 id → refused, `current_id` = v2 id; nothing changed.
5. note → decision promotion, then update of the old note id → refused with current_id.
6. N=6 concurrent updates with the same valid `expected_revision` on a note → exactly 1 success, 5 refused with
   `current_revision` equal to the winner's returned revision.
7. Stale `expected_revision` sequentially → refused, row unchanged (content/tags/revision same).
8. Revision semantics: `memory_get` revision == update output revision (in-place and versioned/new id);
   two successive identical updates produce different revisions; `memory_get` itself does not change revision.
9. Unit test: `MemoryRecord` built from existing fields only has non-empty str `revision`, also in `model_dump()`.
10. Not-found and deleted targets still give -32602.
Confirm (by temporarily stashing your update.py change or reasoning + reporting) that tests 1, 3 and 6 fail without
the fix — at least run test 1 & 3 against the original update.py once and report the result.

## Verify and report
- `alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py <your new tests>` — all pass; run the new
  concurrency tests 3 times in a row to check for flakiness.
- Full suite `pytest -q -p no:cacheprovider` before and after (use `git stash` for the baseline) and report the
  exact failing test lists, to prove no new failures.
- `ruff check src tests`, `ruff format --check` on changed files, `mypy` — report results.
Report: files changed, exact test commands + results, anything uncertain.
