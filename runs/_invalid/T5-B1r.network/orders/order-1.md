# Work order 1 — No lost updates on `memory_update` (revision tokens + row locking)

Read `CLAUDE.md` and `CONVENTIONS.md` first. Follow them.

## Problem
`memory_update` (`src/mem_mcp/mcp/tools/update.py`) reads the target row with a plain SELECT, merges in
Python, then writes. Concurrent callers therefore:
1. lose tag edits (`tags_op="add"/"remove"` merge against a stale read);
2. fork version chains (two concurrent content updates of a `decision`/`fact` both INSERT a new version
   superseding the same parent → two current rows). Same fork happens *sequentially* when a caller updates
   an id that has already been superseded (`is_current = false`) — today nothing checks `is_current`;
3. blindly overwrite each other (no "only if unchanged since I read it" option).

Correctness must come from the database (row locks / conditional writes), NOT in-process locks
(several server workers).

## Design (implement this)

### 1. Migration `alembic/versions/0046_<date>_memory_revision.py`
- `revision = "0046_memory_revision"`, `down_revision = "0045_fix_turn_backfill"` (current head). Match the
  style of existing migrations (raw `op.execute` SQL).
- `ALTER TABLE memories ADD COLUMN revision UUID NOT NULL DEFAULT gen_random_uuid();` (fills existing rows).
  Downgrade drops the column.
- Do NOT add a trigger that bumps revision on every UPDATE: `memory_get` fires a background access-count
  UPDATE (`memory/access_tracking.py`) which must NOT change the revision. Revision is bumped explicitly by
  `memory_update` only.
- Check that the app DB role can see/update the new column under RLS/grants (column-level grants? check
  0001 / later migrations for how `memories` grants are done; add grants if they are column-specific).
- Apply with `alembic upgrade head` on the test DB.

### 2. `MemoryRecord` (`src/mem_mcp/mcp/tools/get.py`)
- Add `revision: str` field that is **optional at construction** (existing callers/tests construct
  `MemoryRecord` without it). If not supplied (or None/empty), a `model_validator(mode="after")` (or
  equivalent) must fill it with a non-empty deterministic string derived from the record (e.g. a short
  sha256 hex of `id|version|updated_at.isoformat()|content`). It must show up in `model_dump()`.
- When the DB row supplies `revision` (a UUID from asyncpg) coerce to `str` (a `mode="before"` validator).
- Add `revision` to every SELECT that feeds `MemoryRecord`: `memory_get` main query AND the recursive
  history CTE (both arms), and `get_batch.py` queries (two places). Grep for others.

### 3. `memory_update` (`src/mem_mcp/mcp/tools/update.py`)
- Input: add `expected_revision: str | None = None`.
- Output: add `revision: str`.
- Initial lookup becomes `SELECT id, type, content, version, tags, metadata, deleted_at, is_current,
  superseded_by, revision FROM memories WHERE id=$1 AND tenant_id=$2 FOR UPDATE`. This row lock serializes
  concurrent updates of the same row; under READ COMMITTED, a waiter re-reads the latest committed row
  version after the lock is granted, so tag merges are computed against fresh data.
  (Verify FOR UPDATE works for the app role under RLS — it needs UPDATE privilege + UPDATE policy, which
  update already uses.)
- After the existing not-found / deleted checks (keep their -32602 errors exactly as they are), in this order:
  a. **Superseded target**: if `is_current` is false → resolve the current id of the chain by following
     `superseded_by` forward (recursive CTE or loop, tenant-scoped, stop at the row with `is_current`;
     guard against cycles / missing links, fall back to the last id found) and raise
     `JsonRpcError(-32000, "memory has been superseded", data={"code": "update_conflict",
     "current_id": str(current_id), "current_revision": <current row's revision as str, if found>})`.
  b. **Stale token**: if `inp.expected_revision is not None` and it != `str(row revision)` → raise
     `JsonRpcError(-32000, "memory was modified concurrently", data={"code": "update_conflict",
     "current_revision": str(row revision), "current_id": str(target id)})`.
  Both before any embedding / quota work.
- **IMPORTANT for existing mock tests** (`tests/unit/test_tools_update.py`, must pass unchanged): mocked
  lookup rows are plain dicts that lack `is_current`, `superseded_by`, `revision` and sometimes `version`.
  Read these via `.get()` with safe defaults (`is_current` default True; asyncpg `Record` supports `.get`).
  In the mocks `conn.fetchval` returns a `datetime` or an unconfigured AsyncMock value, and the versioned
  INSERT mock returns `{"id", "version"}` only — so: revision output must be `str(...)`, and use
  `.get("revision")` on returned rows with a fallback (never crash, never return an empty string).
- In-place path: both UPDATE statements set `revision = gen_random_uuid()` and `RETURNING revision`
  (instead of `updated_at`); return `revision=str(that)`.
- Versioned path: INSERT ... `RETURNING id, version, revision` (new row gets a fresh default revision).
  The UPDATE that supersedes the old row must be conditional: `... WHERE id=$2 AND tenant_id=$3 AND
  is_current RETURNING id` via `fetchval`; if it returns `None` raise the update_conflict error (defence in
  depth; the row lock should already prevent it). Also set `revision = gen_random_uuid()` on the old row
  (it changed). Note: in the mock tests `fetchval` is unconfigured on the versioned path and returns a
  non-None mock — that is fine.
  Output `revision` = the NEW row's revision, which must equal `memory_get(new_id).memory.revision`.
- Every successful update (even a no-op with only `id`) yields a new revision.
- Optionally (nice to have): the web handler `src/mem_mcp/web/handlers/memories.py` `_jsonrpc_to_http`
  maps `update_conflict` to HTTP 409 if trivial; do not change plugin SDK `MemoryClient.update` signature.

### 4. Tool description (`src/mem_mcp/mcp/tool_descriptions.py`, `memory_update` entry)
Append a concise paragraph: optional `expected_revision` (take it from `memory_get` → `memory.revision` or a
previous `memory_update` output `revision`); refused updates return error code -32000 with
`data.code="update_conflict"`, `data.current_revision` (re-read, merge, retry) and `data.current_id`
when the id was superseded (retry against the current version). Mention the output `revision` field.

## Tests to add (do not modify existing tests)
A. Unit tests (mock-based, new file `tests/unit/test_tools_update_conflict.py`): stale
   `expected_revision` → -32000/update_conflict with current_revision, nothing written (no UPDATE/INSERT
   issued); superseded target (`is_current=False`) → -32000 with current_id; `MemoryRecord` built
   without revision has non-empty str revision present in `model_dump()`.
B. Real Postgres concurrency tests, new file `tests/integration/test_update_concurrency.py`. Set up
   tenant+team+identity like `tests/integration/test_mindmap_e2e.py`, create memories with `MemoryWriteTool`
   + stub embedder. Create **your own pool with ≥ 12 connections** (default `pg_pool` has 4), close it at
   the end (let memory_get's background access bump drain first, e.g. small sleep / await pending tasks).
   Each concurrent call must run on its own connection via `asyncio.gather`. Cases:
   1. 8 concurrent `tags_op="add"` each adding a distinct tag → final tags contain all 8.
   2. concurrent `tags_op="remove"` of distinct tags → all removed.
   3. 6 concurrent content updates of the same current `decision` → exactly 1 success (version 2), 5
      update_conflict; chain has exactly one `is_current` row; only one row supersedes the parent.
   4. sequential: update decision (→ v2), then update the old id again → update_conflict with
      `current_id == str(v2 id)`; no new row created. Same for note→decision promotion then updating old id.
   5. 6 concurrent updates with the same valid `expected_revision` → exactly 1 succeeds, rest
      update_conflict with `current_revision`; content equals the winner's.
   6. revision semantics: `memory_get` revision == update output revision (in-place and versioned path,
      for versioned compare with `memory_get(new_id)`); two successive updates give distinct revisions;
      `memory_get` itself (access bump) doesn't change revision; stale token refused and nothing changes.
   Before finishing, temporarily confirm that tests 1/3/5 FAIL without the `FOR UPDATE`/checks (e.g. stash
   the update.py change and run them), then restore. Report that result.

## Acceptance / verification — report exact outputs
- `alembic upgrade head` succeeds.
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_tools_update_conflict.py tests/integration/test_update_concurrency.py` all pass; run the concurrency file 3 times to check for flakiness.
- Full suite `pytest -q -p no:cacheprovider` before (git stash) and after your change: list failing tests in
  both runs and confirm no NEW failures.
- `ruff check src tests` and `mypy` clean for files you touched.
Report: files changed, test results, anything uncertain.
