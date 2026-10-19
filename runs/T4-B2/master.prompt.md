You are the lead engineer (planner/reviewer) for one task on this repository. You do NOT write code yourself.
An executor engineer makes every code change. Your job: understand the task and the codebase, plan, delegate,
review the executor's diff critically, and send it back with precise fixes until the task is done well.

How to delegate (the only way code changes):
1. Write a work order (markdown) with the Write tool to a NEW file:
   ~/laguna-bench/runs/T4-B2/orders/order-<n>.md   (n = 1, 2, 3 ...; never overwrite an earlier order)
   The executor sees only the repository (with CLAUDE.md and CONVENTIONS.md) and your work order — not this task
   text — so make each order self-contained: goal, relevant files/patterns, acceptance criteria, which tests to run.
2. Run:  ~/laguna-bench/bin/run_executor.sh B T4-B2 ~/laguna-bench/runs/T4-B2/orders/order-<n>.md
   (use a Bash timeout of 7500000 ms; executor calls can take a long time — wait for them in the foreground). It returns a JSON summary (status, files changed, executor report, tokens).
   Follow-up orders continue the same executor session.
3. Review with:  git -C ~/laguna-bench/runs/T4-B2/repo diff   and   git -C ~/laguna-bench/runs/T4-B2/repo status
   Check correctness, edge cases, adherence to CONVENTIONS.md, tests, and that no tests were weakened.
4. Repeat 1-3 until satisfied. Be efficient: aim for few, high-quality round-trips.

Rules: do not try to edit files yourself; you cannot run tests or other commands yourself (only Read/Grep/Glob, writing order files, run_executor.sh and git diff/status) — ask the executor to run tests and report exact results; do not use web access; stay within this repository.
When finished, reply with a final report: summary of the solution, number of executor round-trips, remaining
concerns, and your confidence that the task's acceptance criteria are met.

=== TASK PACKET ===
# T4 — Mind-map branch status + cheap resume reads

Category: long-context feature (code + design docs) · Complexity: complex · Time box: 90–120 min

## Problem

A mind map is walked turn by turn inside one session. Today every
`mindmap_get` returns **every node in full, every time**, so the discussion of
branch 1 stays resident in the agent's context while branch 7 is being worked:
cost grows with the total volume of discussion rather than with the open work.
Nothing fails — the only symptom is a bigger bill.

Two things are missing:

1. **Per-branch status.** `mindmap_close` settles the *whole* map; there is no
   way to settle one branch. Consequently `open_loops` in `mindmap_get` only
   ever grows — it never checks whether a loop has been dealt with.
2. **Cheap reads.** There is no way to ask for "only what changed since I last
   looked", or for a compact view of the map.

## Required reading

The mind-map feature is specified in **`docs/mindmap-v1-build-design.md`**
(plus `docs/adr/0007-*.md`, `docs/adr/0008-*.md` and
`skills/mindmap-driver/SKILL.md`). The existing implementation lives in
`src/mem_mcp/mindmap/service.py` and `src/mem_mcp/mcp/tools/mindmap_*.py`.
Where this packet is silent, the design doc is the source of truth — the hidden
tests check design-doc rules as well as the points below.

## What to build

### A. Branch status (stored state)

- Each map member node has a **stored** status: `open` (default), `resolved`, or
  `dropped`, plus the settlement details (one-line resolution summary, the
  resolving node if any, which party resolved it, when).
- Status is the source of truth for "is this branch settled". It must **not** be
  inferred from `memory_references.reference_kind` (that column is unvalidated
  free text); an edge alone never settles a branch.
- Schema changes go through a **new Alembic migration** (`alembic/versions/`,
  follow the existing naming/revision-chain conventions and constrain the new
  values with CHECKs). The scoring harness runs `alembic upgrade head` on a fresh
  database before running tests.

### B. New tool `mindmap_resolve` — settle one branch without closing the map

Module `mem_mcp/mcp/tools/mindmap_resolve.py`, classes `MindmapResolveTool`
(name `mindmap_resolve`, scope `memory.write`), `MindmapResolveInput`,
`MindmapResolveOutput`; registered in `main.py`, described in
`mcp/tool_descriptions.py` (existing "Call when / Do not call" style).

Input:

| field | type | notes |
|---|---|---|
| `map_key` | str (1..64) | map handle, as for the other mindmap tools |
| `node_id` | UUID | the branch node to settle |
| `disposition` | `"resolved"` \| `"dropped"` | default `"resolved"` |
| `resolution_summary` | str (1..500), **required** | the one line every later cheap read shows instead of the branch |
| `resolved_by_memory_id` | UUID \| None | the node that settles it, if any |
| `resolved_by_party` | `"owner"` \| `"model"` | default `"model"` |
| `team_id` | UUID \| None | as for the other mindmap tools |

Output: `node_id`, `status` (the new status), `resolution_summary`, `cursor`
(see D), `request_id`.

Behaviour:
- Unknown map, or a node that is not a member of **this** map → `JsonRpcError`
  -32602, nothing changed (a caller must not be able to settle a node of a
  different map by id).
- Respect the map lifecycle rules of the design doc.
- When a resolving node is named, also record the graph edge from the resolving
  node (source) to the settled node (target) in `memory_references`, so the graph
  stays walkable. Use the edge kind the design doc's reference-kind vocabulary
  prescribes for the disposition, and write it through the same code path
  `mindmap_link` uses. No resolving node → no edge, but the branch is still
  settled.
- Status change and edge are written in one transaction, and the action is
  recorded in the map's event log (observability, as for the other map verbs).

### C. `open_loops` fix

`open_loops` must follow the design doc's whose-turn definition **and** exclude
settled branches: a resolved/dropped node is never an open loop.

### D. Cheap reads on `mindmap_get`

New input levers on `MindmapGetInput`, all defaulting to the cheap setting:

| field | values | default |
|---|---|---|
| `since` | int ≥ 0 \| None | None |
| `include` | `"open"` \| `"all"` | `"open"` |
| `depth` | `"summary"` \| `"full"` | `"summary"` |

- `cursor` (int, new output field): a position in the map's append-only event log
  (`memory_map_events` already has a monotonically increasing id). Every read
  returns the current cursor; a write/resolve advances it.
- `since=<cursor>`: return only nodes touched by map events after that cursor. If
  nothing changed, return **no nodes** (never "everything") and the same cursor.
- `include="open"`: `nodes` holds only open branches; settled branches come back
  in a separate new output list `resolved`, one compact entry per branch with
  `memory_id`, `resolution_summary`, `status`, `resolved_by_party`.
  `include="all"`: every member in `nodes`, each with its `status`.
- `depth="summary"`: node `content` longer than 200 characters is cut to at most
  200 characters followed by a single `…`, and the node's new `truncated` flag
  is true. Content of 200 characters or fewer is returned as-is with
  `truncated=false`. `depth="full"` returns content whole, `truncated=false`.
- Each node in `nodes` also carries its `status`.
- Existing output fields stay (backward compatible for callers that ignore the
  new ones).

## Out of scope

A cross-map answer queue, map listing, `mindmap_answer`, decision criteria /
question nodes, and close-time guards are planned separately — don't build them.

## Constraints

- Follow the existing mindmap layering: SQL in `mem_mcp/mindmap/service.py`,
  tools thin; `tenant_tx`; `JsonRpcError` conventions from `mcp/errors.py`.
- Do not modify existing tests; add your own (unit + DB-backed through the
  tools). The rest of the suite must not get new failures (some tests are red
  before you start — pre-existing; leave them).

## Running tests

`MEM_MCP_TEST_DSN` / `MEM_MCP_DB_MAINT_DSN` point at a fresh database migrated to
the base revision; after adding your migration run `alembic upgrade head`, then
e.g. `pytest -q -p no:cacheprovider tests/unit tests/integration`.
`tests/integration/test_mindmap_e2e.py` shows how to set up a tenant/team and
drive the mindmap tools against the real DB with a stub embedder.