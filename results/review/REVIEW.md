# Blind code review: Memsys benchmark (T1–T6)

Scores are 1–5 (5 = merge as-is). Columns: conv = conventions, layer = layering/design, err = error handling, tests = test quality, spec = spec conformance, scope = scope hygiene, overall = holistic score (not an average). Per-diff details (strongest point, issues, tampering) are in `scores.json`.

## T1: Admin user lookup over MCP

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| 2fcd5d | 4 | 5 | 4 | 4 | 3 | 5 | **4** |
| 7aaa18 | 3 | 3 | 2 | 3 | 2 | 4 | **2** |

2fcd5d has the stronger base class. `__init_subclass__` enforces the `system.*` permission and the `admin.*` audit action, and blocks overriding `__call__`. Denied and error audits are committed on a fresh `system_tx`. Its gaps are in the data contract: the summary has `id` instead of `tenant_id` and no `provider`/`default_team_id`, and the audit `details` lack `via`, `tool` and `required_permission`.

7aaa18 misses several acceptance points:
- 1-character queries are accepted.
- `_clamp_limit` doesn't clamp to 1.
- There is no `count` field.
- It returns a single `system_role` instead of a `system_roles` list.
- Its JOINs return duplicate rows.
- A tenant with no primary identity is reported as not found.

Neither diff tampers with existing tests.

## T2: memory_not_accessible on own memory

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| 02f904 | 4 | 4 | 4 | 4 | 4 | 5 | **4** |
| 6b8e41 | 4 | 4 | 4 | 3 | 5 | 3 | **4** |
| 8fa772 | 5 | 5 | 5 | 5 | 4 | 5 | **5** |
| f6ceba | 4 | 4 | 5 | 4 | 4 | 5 | **4** |

All four diffs found the same root cause: the references machinery gated on `user_effective_team_access` (UETA) only. All four replaced that check with one shared rule at all four sites (`resolve_reference_target`, the hard-delete citer filter, `refs_in`, `refs_out`), and all of them close the old `team_id IS NULL` skip.

- **8fa772** is the cleanest: a SQL function, a bulk helper, a thorough root-cause docstring, and unit plus integration tests.
- **f6ceba** inlines the predicate into the resolving query. This gives the best opacity, at the cost of duplicated SQL branches.
- **6b8e41** is the only one that also mirrors the RLS `team_members`/`visibility='team'` branch, which matches `memory_get` most faithfully. It ships two overlapping test files, one with an odd suffix.
- **02f904** is a correct Python-only fix that keeps the per-row (N+1) queries.

## T3: Team takeover via member-management tools

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| 01d9a7 | 5 | 4 | 4 | 5 | 5 | 5 | **4** |
| 0353f0 | 4 | 4 | 5 | 5 | 5 | 4 | **4** |

Both add a domain-level `require_team_permission` with its own exception, map it to -32603 `missing_permission`, gate before the email lookup, exempt self-removal, and set the 7-role matrix exactly. The two are complementary:
- **01d9a7** has the tidier layering: a single one-line check per tool.
- **0353f0** found a real revocation hole. `get_team_role` falls back to legacy `team_members` rows, so 0353f0 also deletes that row on removal and adds a test for it. It repeats the try/except block in all three tools and uses `from None`.

## T4: Mind-map branch status and cheap reads

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| 82971c | 4 | 4 | 4 | 4 | 5 | 4 | **4** |
| 9403b0 | 4 | 4 | 4 | 5 | 5 | 4 | **4** |
| a14e29 | 3 | 3 | 3 | 2 | 1 | 2 | **2** |
| ac1b54 | 5 | 5 | 5 | 5 | 5 | 4 | **5** |
| e307d9 | 5 | 5 | 5 | 4 | 5 | 5 | **5** |

Four of the five implement the full packet: a CHECK-constrained status migration, the `resolves-under`/`dropped-under` edge, the live-map and root guards, the event-log cursor, cheap defaults, a compact `resolved` list, and the whose-turn `open_loops`.
- **ac1b54** is the most robust. It does everything in one transaction with row locks, handles both jsonb payload shapes, and has an explicit atomicity test.
- **e307d9** is the most concise and readable, with a reusable `_check_settleable` and a domain race error.
- **9403b0** and **82971c** are complete but verbose. They duplicate checks across three transactions, and 82971c also carries some unrelated churn.

**a14e29** gets the read contract wrong:
- Its defaults are `all`/`full` instead of the cheap `open`/`summary`.
- `depth="summary"` blanks the content instead of truncating it.
- `resolved` is a list of UUIDs instead of compact entries.
- `since=0` returns the full map.

It also references the "T4 packet" in code and appends to an existing test file.

## T5: No lost updates (single diff)

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| a0fd14 | 3 | 3 | 5 | 5 | 5 | 3 | **4** |

The behaviour is correct and enforced by the database:
- `FOR UPDATE` serialises writers.
- A superseded target is refused with `current_id` after the lock is taken.
- Revision tokens hash `(id, updated_at)`, with `updated_at` forced to increase strictly.
- The error contract is complete.
- Real `asyncio.gather` concurrency tests run on a 12-connection pool.

The score is held back by noisy, unrelated churn: a blanket `target[...]` → `target.get(...)` rewrite and line re-wrapping that ruff would undo. The chain-walking SQL also sits in the tool module rather than in `memory/versioning.py`.

## T6: Test suite for memory_list and plugin notices

| id | conv | layer | err | tests | spec | scope | overall |
|---|---|---|---|---|---|---|---|
| 63ba92 | 2 | 1 | 2 | 3 | 1 | 1 | **1** |
| 95ac81 | 5 | 5 | 5 | 5 | 5 | 5 | **5** |

**95ac81** follows the rules: tests only, about 165 behaviour-focused tests, and the bugs it found recorded as `xfail(strict=True)` with precise reasons. Only one xfail is non-strict, and that one covers a nondeterministic ordering.

**63ba92** edits `src/mem_mcp/mcp/tools/list.py` and `src/mem_mcp/plugins/notice_delivery.py` to fix the bugs it found, which the packet explicitly calls disqualifying. Its tests assert the patched behaviour, so they would fail on the unmodified source. The bug-finding itself was good.
