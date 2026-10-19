You are the lead engineer (planner/reviewer) for one task on this repository. You do NOT write code yourself.
An executor engineer makes every code change. Your job: understand the task and the codebase, plan, delegate,
review the executor's diff critically, and send it back with precise fixes until the task is done well.

How to delegate (the only way code changes):
1. Write a work order (markdown) with the Write tool to a NEW file:
   ~/laguna-bench/runs/T5-Q1/orders/order-<n>.md   (n = 1, 2, 3 ...; never overwrite an earlier order)
   The executor sees only the repository (with CLAUDE.md and CONVENTIONS.md) and your work order — not this task
   text — so make each order self-contained: goal, relevant files/patterns, acceptance criteria, which tests to run.
2. Run:  ~/laguna-bench/bin/run_executor.sh Q T5-Q1 ~/laguna-bench/runs/T5-Q1/orders/order-<n>.md
   (use a Bash timeout of 7500000 ms; executor calls can take a long time — wait for them in the foreground). It returns a JSON summary (status, files changed, executor report, tokens).
   Follow-up orders continue the same executor session.
3. Review with:  git -C ~/laguna-bench/runs/T5-Q1/repo diff   and   git -C ~/laguna-bench/runs/T5-Q1/repo status
   Check correctness, edge cases, adherence to CONVENTIONS.md, tests, and that no tests were weakened.
4. Repeat 1-3 until satisfied. Be efficient: aim for few, high-quality round-trips.

Rules: do not try to edit files yourself; you cannot run tests or other commands yourself (only Read/Grep/Glob, writing order files, run_executor.sh and git diff/status) — ask the executor to run tests and report exact results; do not use web access; stay within this repository.
When finished, reply with a final report: summary of the solution, number of executor round-trips, remaining
concerns, and your confidence that the task's acceptance criteria are met.

=== TASK PACKET ===
# T5 — No lost updates when several agents edit the same memory

Category: logic-heavy concurrency · Complexity: complex · Time box: 90–120 min

## Problem

Mind-map nodes are ordinary memories (`position`, `challenge`, `note`, …) and
are edited in place with `memory_update`. With several agents working the same
map at once we see silent data loss:

1. **Lost tag edits.** Agent A adds tag `x` and agent B adds tag `y` to the same
   node at the same moment; afterwards the node has only one of them.
   (`tags_op="add"`/`"remove"` merges in Python against a row it read earlier.)
2. **Forked version chains.** Two agents update the content of the same
   `decision` (a versioned type) concurrently; both calls "succeed" and the chain
   now has **two current versions** superseding the same parent. The same fork
   happens without any concurrency if a caller updates an id that has already
   been superseded (it still holds an old id).
3. **Blind overwrites.** Agent A reads a node, thinks for a minute, writes its
   rewrite; meanwhile agent B rewrote the node. A's write silently discards B's.
   There is no way for a caller to say "only apply this if the memory is still
   what I read".

Relevant code: `src/mem_mcp/mcp/tools/update.py` (memory_update),
`src/mem_mcp/mcp/tools/get.py` (memory_get, `MemoryRecord`),
`src/mem_mcp/memory/versioning.py`, `src/mem_mcp/db/tenant_tx.py`.

## Required behaviour

### Revision tokens (optimistic concurrency)

- Every memory has a **revision**: an opaque string that changes whenever the
  memory is changed by `memory_update` (content, tags, type or metadata — any
  successful update yields a new revision; two successive updates never yield
  the same revision).
- `memory_get` exposes it as `memory.revision` (a `revision` field on
  `MemoryRecord`, so it also appears on history records and anywhere else
  `MemoryRecord` is returned). `MemoryRecord` must stay constructible from its
  existing fields alone (no new required constructor argument), and a record
  built that way must still report a non-empty string `revision` (including in
  `model_dump()`).
- `memory_update` output gains `revision`: the revision of the row that now holds
  the memory (on the versioned path, the **new** row's revision — it must equal
  what `memory_get(new_id)` reports).
- `memory_update` input gains optional `expected_revision: str | None`. When
  given and it does not equal the memory's current revision, the update is
  refused and **nothing changes**. When omitted, behaviour is as today
  (subject to the rules below).
- The check and the write must be atomic: if N callers concurrently send
  updates with the same (currently valid) `expected_revision`, **exactly one**
  succeeds and the other N−1 are refused.

### Serialized updates (no lost updates even without a token)

- Concurrent `memory_update` calls on the same memory must behave as if they ran
  one after another: concurrent `tags_op="add"` / `"remove"` calls all take
  effect (none is lost); in-place content updates are last-writer-wins.
- A version chain never has more than one current row. Updating a memory that is
  no longer current (it has been superseded, e.g. by a versioned content update
  or a note→decision type promotion) is refused — whether the caller is late by
  a millisecond (concurrent) or by a day (sequential). Of N concurrent content
  updates to the same current `decision`, exactly one creates version 2; the
  others are refused.

### Conflict error contract

A refused update raises `JsonRpcError` with code **-32000** (application error)
and `data["code"] == "update_conflict"`, plus:
- `data["current_revision"]` — the memory's current revision (when refused for a
  stale `expected_revision`), so the caller can re-read, merge and retry;
- `data["current_id"]` — the id (string) of the current version of the chain
  (when refused because the target was superseded).

Not-found / deleted targets keep their existing -32602 errors.

Document the new parameter and the conflict contract in the `memory_update`
tool description (`mcp/tool_descriptions.py`).

## Constraints

- Correctness must come from the database (row locking / conditional writes /
  constraints), not from in-process locks — the server runs several workers.
- Keep the existing layering (`tenant_tx`, `JsonRpcError`). If you need a schema
  change, add a new Alembic migration (`alembic/versions/`, next revision after
  the current head); the scoring harness runs `alembic upgrade head` on a fresh
  database before tests. A solution without a migration is fine.
- Backward compatible: existing callers that never send `expected_revision`
  keep working; existing unit tests for `memory_update` (mock-based, in
  `tests/unit/test_tools_update.py`) and the web/plugin callers must keep
  passing. Do not change the plugin SDK's `MemoryClient.update` signature.
- Do not modify existing tests. Add your own, including **real concurrency
  tests against Postgres** (e.g. `asyncio.gather` of several updates, each on its
  own pooled connection — create a pool larger than the default `pg_pool`
  fixture's 4 connections) that fail without your fix.
- The rest of the suite must not get new failures (some tests are red before
  you start — pre-existing; leave them).

## Running tests

`MEM_MCP_TEST_DSN` (and `MEM_MCP_DB_MAINT_DSN` for alembic) point at a fresh
migrated Postgres. Run e.g. `pytest -q -p no:cacheprovider tests/unit tests/integration`.
To create memories in DB-backed tests, set up a tenant + team + primary identity
with `default_team_id` (see `tests/integration/test_mindmap_e2e.py`) and use
`MemoryWriteTool` with a stub embedder. Note `memory_get` fires a background
access-count update; let it drain before closing a pool you created.