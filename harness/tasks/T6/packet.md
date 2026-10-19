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
