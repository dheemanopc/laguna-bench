# Work order 8 — memory_list DB: tags edges, since/until, keywords (TESTS ONLY, small)

Keep tool output short. Add these tests to a NEW file
`tests/integration/test_memory_list_filters_db.py` (import helpers `_setup_tenant_and_team`,
`_cleanup_tenant`, `_build_ctx`, `_insert_memory` from `tests.integration.test_memory_list_db`).
`pytestmark = pytest.mark.asyncio`. Each test: own tenant, try/finally cleanup, exact assertions.

1. `test_tags_edge_cases` — `a, b, c = (f"t-{uuid4().hex[:8]}" for _ in range(3))`. Memories
   ab=[a,b], ma=[a], mb=[b], abc=[a,b,c], none=[]. Assert by id sets:
   `tags=[a,b]` → {ab, abc}; `tags=[b,a]` → {ab, abc}; `tags=[a]` → {ab, ma, abc};
   `tags=[a,b,c]` → {abc}; `tags=[]` → {ab, ma, mb, abc, none}; `tags=[f"zzz-{uuid4().hex}"]` → set().
2. `test_since_only_until_only` — T = `datetime(2026, 3, 1, 12, tzinfo=UTC)`; memories at
   T-1s (p), T (q), T+1s (r). `since=T` → {q, r}; `until=T` → {p, q};
   `since=T+timedelta(microseconds=1)` → {r}; `until=T-timedelta(microseconds=1)` → {p};
   `since=T, until=T` → {q}.
3. `test_keywords_filter_order_and_preview` — insert (created_at base+1..4 min):
   m1 "Postgres runs fast", m2 "we chose redis", m3 "nothing relevant here", m4 "the postgres planner".
   - `keywords="postgres"` → `[r.id ...] == [m4, m1]` (created_at desc, not relevance)
   - `keywords="postgres", order="asc"` → `[m1, m4]`
   - `keywords="redis postgres"` → `[m4, m2, m1]`
   - `keywords="running"` → `[m1]` (stemming)
   - `keywords="the a"` → `[]`; `keywords="kubernetes"` → `[]`
   - for `keywords="postgres"`: preview of m1 contains `"**Postgres**"`, preview of m4 contains
     `"**postgres**"`; `content` of each == original content exactly.
   - no keywords: for all four, `preview == content == original` exactly.
   FIRST check how `content_tsv` is populated (grep alembic for `content_tsv`). If a direct insert
   doesn't populate it, make the test populate it the same way the app/migration does. If the
   assertions fail, show me the actual values rather than weakening them.
4. `test_keywords_long_content` — `original = "postgres " + " ".join(f"word{i}" for i in range(600))`
   (> 2000 chars). With `keywords="postgres"`: `"**postgres**" in preview`, `len(preview) <= 600`,
   `content == original[:2000]`, `len(content) == 2000`. Without keywords: `preview == original[:280]`.
5. `test_keywords_combined_with_tags` — m1 "postgres tuning" tags=[a], m2 "postgres backups" tags=[b],
   m3 "redis" tags=[a] → `keywords="postgres", tags=[a]` → `[m1]`.

Run:
`pytest -q -p no:cacheprovider tests/integration/test_memory_list_filters_db.py -rxX 2>&1 | tail -20`
and paste verbatim. If anything needed an xfail, give the observed value.
