You are the lead engineer (planner/reviewer) for one task on this repository. You do NOT write code yourself.
An executor engineer makes every code change. Your job: understand the task and the codebase, plan, delegate,
review the executor's diff critically, and send it back with precise fixes until the task is done well.

How to delegate (the only way code changes):
1. Write a work order (markdown) with the Write tool to a NEW file:
   ~/laguna-bench/runs/T6-B1/orders/order-<n>.md   (n = 1, 2, 3 ...; never overwrite an earlier order)
   The executor sees only the repository (with CLAUDE.md and CONVENTIONS.md) and your work order — not this task
   text — so make each order self-contained: goal, relevant files/patterns, acceptance criteria, which tests to run.
2. Run:  ~/laguna-bench/bin/run_executor.sh B T6-B1 ~/laguna-bench/runs/T6-B1/orders/order-<n>.md
   (use a Bash timeout of 7500000 ms; executor calls can take a long time — wait for them in the foreground). It returns a JSON summary (status, files changed, executor report, tokens).
   Follow-up orders continue the same executor session.
3. Review with:  git -C ~/laguna-bench/runs/T6-B1/repo diff   and   git -C ~/laguna-bench/runs/T6-B1/repo status
   Check correctness, edge cases, adherence to CONVENTIONS.md, tests, and that no tests were weakened.
4. Repeat 1-3 until satisfied. Be efficient: aim for few, high-quality round-trips.

Rules: do not try to edit files yourself; you cannot run tests or other commands yourself (only Read/Grep/Glob, writing order files, run_executor.sh and git diff/status) — ask the executor to run tests and report exact results; do not use web access; stay within this repository.
When finished, reply with a final report: summary of the solution, number of executor round-trips, remaining
concerns, and your confidence that the task's acceptance criteria are met.

=== TASK PACKET ===
# T6 — Test suite for `memory_list` and the plugin-notice pipeline

Category: test writing · Complexity: standard · Time box: 90–120 min

## Goal

Two areas have thin, mostly mock-based coverage and have regressed before
(e.g. the tag filter once matched ANY instead of ALL tags; plugin notices once
crashed on datetime payloads). Write a thorough, behaviour-focused test suite
for them. **Do not modify any source code** — tests only.

Modules under test:

1. `src/mem_mcp/mcp/tools/list.py` — the `memory_list` MCP tool
   (`MemoryListTool`, its input/output models, and the cursor helpers).
   Behaviour to pin down includes: tenant scoping; the tag filter (memories must
   carry **all** requested tags); `type`; `since`/`until`; `team_id`;
   `indexable`; `parent_id`; `include_deleted` / `include_expired` /
   `include_history`; the lenient `keywords` filter and the `preview` field
   (keyword-windowed snippet with `**match**` markers vs head-of-content);
   `content` truncation; `order_by` / `order`; `limit`; `next_cursor` and
   pagination; invalid cursors → JSON-RPC -32602; the audit call.
   The tool description in `src/mem_mcp/mcp/tool_descriptions.py`
   (`"memory_list"`) is the behavioural contract.
2. `src/mem_mcp/plugins/clients/notices.py` (`NoticeClientImpl.queue`, payload
   serialization) and `src/mem_mcp/plugins/notice_delivery.py`
   (`deliver_pending`, template rendering, `RenderedNotice.to_dict`): queueing
   with TTL, payloads containing datetimes/dates/UUIDs, oldest-first delivery,
   `limit`, at-most-once delivery, expiry, tenant isolation, `{placeholder}`
   rendering including missing keys, and the serialized shape.

## How you are scored

- Your tests are run by **mutation testing** (mutmut) restricted to the three
  modules above: the score is the fraction of generated mutants that your tests
  (together with the existing tests for these modules) kill. Assert on
  observable behaviour precisely — exact values, exact sets, exact error codes —
  rather than "doesn't crash".
- Your new tests must pass on the current, unmodified source.
- Mutation testing runs your tests hundreds of times, in parallel worker
  processes, against **one shared database**. Tests must therefore be
  deterministic and isolated: create your own tenants/teams with UUID-suffixed
  emails, never assume an empty table, never depend on test order, and do not
  rely on wall-clock races. Keep the whole new suite fast (seconds, not minutes).
- No network: no real Bedrock/Cognito/etc. Use stub embedders (see existing
  tests) — `MemoryWriteTool` needs one.

## If you find a bug

Do not fix it (source changes are disqualifying). Write the test that shows the
correct behaviour and mark it `@pytest.mark.xfail(strict=True, reason="BUG: …")`,
so the suite stays green today and flips red when someone fixes the bug without
updating the test. List every bug you found, with a one-line explanation, in your
final report. Correctly identified real bugs are credited separately.

## Rules

- Add **new** test files only (under `tests/unit/` or `tests/integration/`);
  do not edit existing tests, `conftest.py` files, `pyproject.toml`, or anything
  under `src/`, `alembic/`.
- DB-backed tests use the `pg_pool` fixture (`tests/conftest.py`) and need a
  tenant + team + primary identity with `default_team_id`, plus an
  `oauth_clients` row for the `client_id` you put in the `ToolContext` (memories
  reference it); see `tests/integration/test_mindmap_e2e.py` for the pattern.

## Running tests

`MEM_MCP_TEST_DSN` points at a fresh migrated Postgres. Run e.g.
`pytest -q -p no:cacheprovider tests/unit/test_tools_list.py <your files>`.