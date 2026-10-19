# Work order 1 — No lost updates on `memory_update` (revision tokens + DB-level serialization)

Read `CLAUDE.md` and `CONVENTIONS.md` first and follow them.

## Problem
Concurrent `memory_update` calls on the same memory (`src/mem_mcp/mcp/tools/update.py`) lose data:
1. `tags_op="add"/"remove"` merges in Python against a row read earlier without a lock, so concurrent tag adds get lost.
2. Two concurrent versioned content updates (type `decision`/`fact`, see `memory/versioning.py`) both insert a new
   version superseding the same parent, so the chain ends up with two current rows. The same fork happens
   sequentially if a caller updates an id that is already superseded.
3. There's no optimistic-concurrency token, so a caller can't say "only apply this if the memory is still what I read".

Correctness must come from Postgres (row locks / conditional writes), **not** in-process locks (several workers).

## Required behaviour

### A. Revision column (new Alembic migration)
- Add `alembic/versions/0046_<date>_memory_revision.py` (revision id e.g. `0046_memory_revision`,
  `down_revision` = the revision id declared in `0045_2026_08_12_fix_turn_backfill_double_encoded.py`; check the
  exact string). It adds `memories.revision UUID NOT NULL DEFAULT gen_random_uuid()`, with a working downgrade.
  Match the style of the existing migrations. Check grants and RLS: the app role must be able to read and write
  the column (column-level grants, if any are used anywhere, need to include it).
- The revision is an **opaque string** to callers: expose it as `str(uuid)`.
- `memory_update` sets a **fresh revision generated in Python** (`uuid4()`) on every successful write:
  - in-place path: `SET ..., revision = $n`;
  - versioned path: the INSERTed new row gets the fresh revision explicitly (`revision` column in the INSERT). The
    old superseded row may keep its revision or get a new one; either is fine.
  Generating it in Python means the output's revision is known without reading it back. This matters because the
  existing mock-based unit tests return INSERT rows with only `{id, version}`.
- Also bump `revision` in the `write.py` dedupe-merge path (around line 346, the `UPDATE memories ... updated_at = now()`
  that unions tags into an existing row), so a token can't stay valid across that change. Do not bump it anywhere
  else, especially not in the background access-count update (`bump_access`). A read must not change the revision.

### B. `MemoryRecord` (`src/mem_mcp/mcp/tools/get.py`)
- Add a `revision: str` field that is **optional at construction** (no new required argument). A record built
  from the existing fields alone must still report a **non-empty string** revision, including in `model_dump()`.
  Suggested: `revision: str = ""` plus a `model_validator(mode="after")` that, when it is empty, fills it with a
  deterministic fallback derived from the record (e.g. sha256 of `f"{id}:{version}:{updated_at.isoformat()}"`,
  truncated). Accept a UUID value too (coerce it to `str`) via a `field_validator(mode="before")`.
- Every SQL that feeds `MemoryRecord(**row)` must select the real revision: `revision::text AS revision`. That
  includes the main row and the recursive history CTE in `get.py` (both branches; use `m.revision` in the
  recursive branch) and both queries in `get_batch.py`. Grep for other `MemoryRecord(` constructors and fix those
  too.

### C. `memory_update` input/output
- `MemoryUpdateInput` gains `expected_revision: str | None = None`.
- `MemoryUpdateOutput` gains `revision: str`: the revision of the row that now holds the memory. On the versioned
  path that is the **new** row's revision, and it must equal what `memory_get(new_id)` reports.

### D. Serialization and conflict logic in `MemoryUpdateTool.__call__`
Inside the existing `tenant_tx`:
1. The initial lookup becomes `SELECT id, type, content, version, tags, metadata, deleted_at, is_current,
   superseded_by, revision::text AS revision FROM memories WHERE id=$1 AND tenant_id=$2 FOR UPDATE`. This row lock
   serializes concurrent updates of the same row. Under READ COMMITTED, a waiter re-reads the latest committed row
   version after the lock is released, so the tag merge and the checks below see fresh data. Verify that the RLS
   policies allow `FOR UPDATE` for the app role. If `FOR UPDATE` on a row the caller can SELECT but not UPDATE is a
   concern, note it in your report.
2. Keep the order: not found → existing -32602; deleted → existing -32602 (unchanged messages and data).
3. **Superseded target:** if `is_current` is false or `superseded_by` is not NULL → raise
   `JsonRpcError(-32000, "memory has been superseded", data={"code": "update_conflict", "current_id": "<str id of the current version of the chain>", ...})`.
   Find the current id by walking `superseded_by` forward with a recursive CTE (tenant-scoped) to the row whose
   `superseded_by IS NULL`. Also include `current_revision` of that row if convenient.
4. **Stale token:** if `inp.expected_revision is not None` and it differs from the locked row's revision → raise
   `JsonRpcError(-32000, "revision mismatch", data={"code": "update_conflict", "current_revision": <row revision>, "current_id": str(row id)})`.
5. Versioned path: the UPDATE that marks the old row superseded must be conditional
   (`... WHERE id=$2 AND tenant_id=$3 AND is_current AND superseded_by IS NULL`) as a belt-and-braces guard. If it
   reports `UPDATE 0`, raise the same superseded conflict. Use `conn.execute` and compare the status string to
   `"UPDATE 0"`. The existing mocks return a non-string from `execute`, and that must be treated as success. Do the
   conditional UPDATE before or after the INSERT, whichever is clean, as long as everything stays in one transaction.
6. In-place path: write the new revision; `RETURNING` whatever you need.
7. Look at `JsonRpcError` / `mcp/errors.py` and CONVENTIONS.md for how application errors (-32000) and `data`
   are conventionally shaped, and follow that.

**Mock compatibility (critical):** the existing `tests/unit/test_tools_update.py` must pass unmodified. Its fake
`conn.fetchrow` returns dicts **without** `is_current`, `superseded_by` or `revision`, and on the versioned path
`fetchrow.side_effect` is a list of exactly 2 items (lookup, INSERT). So:
- read the new keys defensively (`row.get("is_current", True)`, `row.get("superseded_by")`, `row.get("revision")`),
  and handle a `None` revision when comparing (a missing revision with a given `expected_revision` → treat as a
  mismatch, or document what you chose);
- add **no extra `fetchrow` calls** on the success paths (use `execute`/`fetchval`/`fetch` for any extra queries,
  or only query on the conflict path);
- `fetchval` returns a `datetime` in those mocks, so don't build the output revision from its return value: use
  the Python-generated revision.

Do not change the plugin SDK `MemoryClient.update` signature. Check the web/plugin callers of `MemoryUpdateTool` /
`MemoryUpdateOutput` (grep for them) and make sure they still work.

### E. Tool description
Update `"memory_update"` in `src/mem_mcp/mcp/tool_descriptions.py`: document `expected_revision` (taken from
`memory_get`'s `memory.revision`, or from a prior update's `revision` output) and the conflict contract:
-32000 with `data.code == "update_conflict"`, `data.current_revision` for a stale token, and `data.current_id`
when the target was superseded. Tell callers to re-read, merge and retry. If any test checks description
length or format, keep it passing.

## Tests to add (do not modify existing tests)
1. Unit tests (mock-based, new file e.g. `tests/unit/test_tools_update_conflicts.py`): stale `expected_revision` →
   -32000/update_conflict/current_revision; superseded target → conflict with current_id; matching token → success;
   output includes a revision; `MemoryRecord` without revision → non-empty string revision in `model_dump()`.
2. **Real concurrency integration tests against Postgres** (new file e.g.
   `tests/integration/test_memory_update_concurrency.py`). Follow `tests/integration/test_mindmap_e2e.py` for
   tenant + team + primary identity with `default_team_id` setup, and use `MemoryWriteTool` with a stub embedder.
   Create your **own** asyncpg pool with e.g. `min_size=max_size=10` from `MEM_MCP_TEST_DSN`, built the same
   way the `pg_pool` fixture in `tests/conftest.py` builds it (same init/codecs), so each concurrent call gets its
   own connection. Skip when the DSN is unset. `memory_get` fires a background access-count update, so let it drain
   before closing your pool. Clean up what you create. Cases:
   - 8 concurrent `tags_op="add"` with distinct tags on one note → all 8 tags present afterwards.
   - concurrent `tags_op="remove"` of distinct tags → all removed.
   - 5 concurrent content updates on one current `decision` → exactly 1 success with version 2; 4 raise -32000
     update_conflict with `current_id` == the winner's id; the chain has exactly one `is_current` row.
   - N (e.g. 6) concurrent in-place updates on a note, all with the same valid `expected_revision` → exactly 1
     succeeds, N−1 get update_conflict with `current_revision` equal to the winner's output revision.
   - sequential: update a superseded decision id (an old id) → conflict with current_id; note→decision type
     promotion, then update the old note id → conflict with current_id.
   - `memory_get(...).memory.revision` matches the update's output `revision` (versioned path: `memory_get(new_id)`);
     two successive updates yield different revisions; a `memory_get` (access bump) does not change the revision;
     the history records carry revisions.
   - concurrent in-place content updates without a token all succeed (last writer wins, no error).
   Confirm that the concurrency tests **fail without the fix**: e.g. temporarily stash the `update.py` change
   (or remove `FOR UPDATE`), run them, report the failures, then restore. Do not leave that change in place.

## Verification (report exact results)
- `alembic upgrade head` (and say whether downgrade -1 / upgrade head round-trips cleanly).
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py <your new tests>`
- Full suite `pytest -q -p no:cacheprovider` **before** your change (run it first, record the failing test ids)
  and after it. Report any difference in failures.
- `ruff check src tests` and `mypy` clean for the files you touched.

Report: files changed, design summary, exact test commands and results, and anything uncertain.
