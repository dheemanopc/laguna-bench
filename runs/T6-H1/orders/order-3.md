# Work order 3 — memory_list DB tests: pagination, cursors, keywords (TESTS ONLY)

Order 2 was only partially done: none of section A items 6–8 exist yet, and
`tests/integration/test_plugin_notices_db.py` was not changed at all. This order covers ONLY
the memory_list integration work. (Notices come in the next order.) Same hard rules as before:
new test files only; never touch `src/`, `alembic/`, conftest, pyproject, pre-existing tests.

**Reporting requirement:** paste the RAW tail of pytest output (the `-rxXs` summary lines and
the final counts line) in your report, not a paraphrase. If any test is SKIPPED, say why.

## Step 0 — prove the DB file runs
Run `pytest -q -p no:cacheprovider tests/integration/test_memory_list_db.py -rxXs` and paste the
output. If tests are skipped (e.g. `MEM_MCP_TEST_DSN` not picked up) or error, fix that first
(in your test file only). Every test in that file must actually execute against Postgres.

## Step 1 — add to `tests/integration/test_memory_list_db.py` (or a second new file
`tests/integration/test_memory_list_pagination_db.py`)

Use explicit, distinct `created_at`/`updated_at` values. Assert exact id lists.

1. **Pagination walk, desc by created_at** — 5 memories m0..m4 with created_at base+0..4 min.
   Expected full order: [m4, m3, m2, m1, m0]. Page 1 (`limit=2`): assert exactly `[m4, m3]`, and
   `_decode_cursor(next_cursor) == (m2.created_at.isoformat(), str(m2))` (the cursor points at the
   first row NOT returned — pin that as current behaviour in a passing test).
   Then the full walk: loop passing `cursor=next_cursor` until it is None (cap at 10 iterations),
   collecting ids. Correct behaviour: collected == [m4, m3, m2, m1, m0].
   Run it and observe. If it raises (e.g. asyncpg DataError because the ISO string is bound to a
   timestamptz param) or skips rows (e.g. m2 missing because the predicate is strict `<` against
   the overflow row), mark the full-walk test `@pytest.mark.xfail(strict=True, raises=<exact exc
   type if it raises>, reason="BUG: <exact observed failure>")`. Put the page-1 assertions in a
   separate, passing test.
2. Same full walk for `order="asc"` (expected [m0..m4]) and for `order_by="updated_at"` where the
   updated_at order differs from created_at order. Separate tests, same treatment.
3. If the walk raises because of the str-vs-timestamptz binding, ALSO write a test that shows
   whether the skip-a-row problem exists independently: call the tool with a hand-made cursor
   that is still the overflow row… actually you can't bypass the binding through the tool. In
   that case, just document both issues in the xfail reason and in your report (the skip bug is
   visible from the code: cursor = `rows[limit]` + strict comparison). Don't fake it.
4. **Tie-break**: three memories with the SAME created_at and `limit=1`, desc walk. Correct =
   each id exactly once. Same xfail treatment (it'll likely fail for the same reason as 1; then
   name both in the reason).
5. **Invalid cursors through `MemoryListTool.__call__` on the real DB** — parametrized.
   Expected for all: `JsonRpcError` with `.code == -32602`, `.message == "invalid cursor"`,
   `.data["errors"][0]["path"] == "cursor"`.
   - Passing group: `"not-base64!!!"`, b64(`b"not json"`), b64(`b"[]"`), b64(`b'["x"]'`), b64(`b"\xff\xfe"`).
   - Check group (one test each; strict xfail with the real observed exception if not -32602):
     b64(`b"{}"`), b64(`b"5"`), b64(`b"null"`), b64(`b'"s"'`),
     b64 of `["2026-01-01T00:00:00+00:00", "not-a-uuid"]`,
     b64 of `["yesterday", "<a valid uuid>"]`.
   Use `pytest.param(..., marks=pytest.mark.xfail(strict=True, reason="BUG: ..."))` for the
   failing ones so each case is pinned individually.
6. **Tags** (exact sets): memories ab=[a,b], a=[a], b=[b], abc=[a,b,c], none=[] (use
   UUID-suffixed tag strings to be safe). `tags=[a,b]` == {ab, abc}; `tags=[a]` == {ab, a, abc};
   `tags=[]` == all five; `tags=["zzz-<uuid>"]` == set().
7. **since only / until only**: memories at T-1s, T, T+1s. `since=T` == {T, T+1s};
   `until=T` == {T-1s, T}; `since=T+1µs` == {T+1s}; `until=T-1µs` == {T-1s}.
8. **keywords**: contents (with explicit created_at c1<c2<c3<c4):
   1 "Postgres runs fast", 2 "we chose redis", 3 "nothing relevant here", 4 "the postgres planner".
   - `keywords="postgres"` → ids exactly `[4, 1]` (created_at desc order, not relevance);
   - `keywords="redis postgres"` → `[4, 2, 1]`;
   - `keywords="running"` → `[1]` (stemming);
   - `keywords="the a"` → `[]`; `keywords="kubernetes"` → `[]`;
   - for `keywords="postgres"`: preview of 1 contains `"**Postgres**"`, preview of 4 contains
     `"**postgres**"`; content fields unchanged (== original content);
   - without keywords, `preview == content[:280]` exactly for each.
   - 3000-char content with the keyword in the first 100 chars: `"**kw**" in preview`,
     `len(preview) <= 600`, `len(content) == 2000`, `content == original[:2000]`.
   (If `content_tsv` isn't populated by your direct insert, find out how it's generated — trigger,
   generated column, or the write path — and set it up correctly; don't drop the tests.)
9. **Field round-trip**: insert one memory with version=3, is_current=True, indexable=False,
   tags=[x,y], type="fact", a future expires_at, a non-default valid embedding_status (check
   the CHECK constraint), and assert every `MemoryListItem` field equals the inserted value
   (with `include_history` etc. as needed). Also one with `deleted_at` set via `include_deleted=True`
   asserting `deleted_at` equals the inserted timestamp.
10. **All include flags true** with one deleted, one expired, one non-current, one normal →
    exact set of all four; each flag alone adds exactly its row.
11. **limit edge**: `limit=1` with exactly 1 row → `next_cursor is None`; with 2 rows → not None and
    exactly the newest row returned.
12. **Audit (real)**: check `mem_mcp.audit.logger` for a real DB-writing audit logger. If one exists
    and is usable in tests, use it in the ctx and assert the `memory.list` row's result and details
    `{"result_count": N, "has_next": bool, "filters_count": 3}` exactly. If not practical, say so.

## Verification
- Raw output of: `pytest -q -p no:cacheprovider tests/integration/test_memory_list_db.py <new file if any> -rxXs`
- 3 consecutive runs + 2 concurrent copies of those files (paste final count lines).
- `ruff check` + `ruff format --check` on the files.
- Report every bug with its test id and the exact observed failure.
