# Work order 13 — exact SQL/params/audit unit tests for memory_list (TESTS ONLY)

Create a NEW file `tests/unit/test_memory_list_sql_exact.py`. No DB. Patch
`mem_mcp.mcp.tools.list.tenant_tx` with an asynccontextmanager yielding a fake conn whose
`fetch = AsyncMock(return_value=rows)`. Use a **recording audit fake**:
```python
class RecordingAudit:
    def __init__(self): self.calls = []
    async def audit(self, conn, **kw): self.calls.append((conn, kw))
```
in `ToolDeps(embeddings=MagicMock(), audit=rec, quotas=NoopQuotas())`. Fixed ctx values:
`tenant = UUID("11111111-1111-1111-1111-111111111111")`, identity `2222...`, `client_id="client-x"`,
`request_id="req-1"`. Helper `run(inp, rows=[])` returning `(out, query, params, rec)` where
`query, *params = conn.fetch.call_args.args`.

Write these tests with EXACT assertions:

1. Default: `params == [tenant, 26]`; `"WHERE (tenant_id = $1) AND (deleted_at IS NULL) AND ((expires_at IS NULL OR expires_at > NOW())) AND (is_current = true)\n" in query`;
   `"ORDER BY created_at DESC, id\n" in query`; `"LIMIT $2\n" in query`;
   `"LEFT(content, 2000) AS content" in query`; `"LEFT(content, 280) AS preview" in query`;
   `"ts_headline" not in query`; `"content_tsv" not in query`; `"FROM memories" in query`.
   (Check the actual whitespace in the generated query first and adapt the `\n` anchors so they're
   exact but correct.)
2. All include flags True, no filters: `params == [tenant, 26]`, `"WHERE (tenant_id = $1)\n"` in query
   (exact, i.e. nothing else in WHERE); `"deleted_at IS NULL" not in query`, `"expires_at" not in query.split("FROM")[1]`,
   `"is_current = true" not in query`.
3. Each include flag alone (parametrize over the 3): only that clause disappears; the other two remain.
4. Single filters (parametrize), each with defaults otherwise — assert `params == [tenant, value, 26]`,
   the clause string, and `"LIMIT $3"`:
   - type="decision" → `"(type = $2)"`
   - tags=["python","async"] → `"(tags @> $2)"`
   - since=S → `"(created_at >= $2)"`
   - until=U → `"(created_at <= $2)"`
   - team_id=T → `"(team_id = $2)"`
   - indexable=True → `"(indexable = $2)"` (and `params[1] is True`)
   - indexable=False → `"(indexable = $2)"` (and `params[1] is False`)
   - parent_id=P → `"(parent_id = $2)"`
   - keywords="postgres async" → `"(content_tsv @@ to_tsquery('english',"` in query and `"$2"` inside the
     tsquery part, and in the preview select.
5. Keywords preview select exact: assert these literal substrings (hardcode numbers):
   `"LEFT(COALESCE(ts_headline('english', LEFT(content, 8000), "`,
   `"'StartSel=**, StopSel=**, MaxFragments=2, MaxWords=30, MinWords=8, FragmentDelimiter=\" … \"'), LEFT(content, 280)), 600) AS preview"`
   and `"LEFT(content, 280) AS preview" not in query` (the plain fallback select is replaced).
   Also assert `query.count("$2") == 2` (where-clause tsquery + headline tsquery reuse the same param).
6. All filters + cursor + limit=7 (desc, created_at): cursor = `_encode_cursor(datetime(2026,1,1,tzinfo=UTC), UUID("3333..."))`.
   `params == [tenant, "fact", ["a","b"], S, U, T, False, P, "kw", "2026-01-01T00:00:00+00:00", "33333333-3333-3333-3333-333333333333", 8]`
   and clauses `(type = $2)`, `(tags @> $3)`, `(created_at >= $4)`, `(created_at <= $5)`, `(team_id = $6)`,
   `(indexable = $7)`, `(parent_id = $8)`, `$9` in tsquery, `((created_at, id) < ($10, $11::uuid))`, `LIMIT $12`.
7. Cursor predicates (params `[tenant, iso, id_str, 26]`) — parametrize 4 combos:
   created_at/desc `((created_at, id) < ($2, $3::uuid))`; created_at/asc `((created_at, id) > ($2, $3::uuid))`;
   updated_at/desc `((updated_at, id) < ($2, $3::uuid))`; updated_at/asc `((updated_at, id) > ($2, $3::uuid))`.
8. ORDER BY — 4 combos exact: `"ORDER BY created_at DESC, id"`, `"ORDER BY created_at ASC, id"`,
   `"ORDER BY updated_at DESC, id"`, `"ORDER BY updated_at ASC, id"`; and for updated_at, `"ORDER BY created_at" not in query`.
9. next_cursor: rows r0..r3 with DISTINCT created_at (2026-01-0{1..4}) and updated_at (2026-02-0{1..4}).
   - `limit=3`, default order_by → `[x.id for x in out.results] == [r0,r1,r2 ids]`,
     `out.next_cursor == _encode_cursor(r3["created_at"], r3["id"])`.
   - `limit=3, order_by="updated_at"` → `out.next_cursor == _encode_cursor(r3["updated_at"], r3["id"])`.
   - `limit=4` with 4 rows → `next_cursor is None`, 4 results. `limit=5` with 4 rows → None.
10. Audit exact (one call each; `rec.calls[0][0] is conn`):
    - default, 5 rows: kw == `{"action": "memory.list", "result": "success", "tenant_id": tenant, "identity_id": identity,
      "client_id": "client-x", "request_id": "req-1", "details": {"result_count": 5, "has_next": False, "filters_count": 3}}`
    - limit=2, 3 rows → details `{"result_count": 2, "has_next": True, "filters_count": 3}`
    - all include flags True, no filters, 0 rows → `{"result_count": 0, "has_next": False, "filters_count": 0}`
    - scenario 6 with 0 rows → filters_count = the real number (should be 3+8+1 = 12 — verify, assert exactly).
11. Errors:
    - `deps=None` → `JsonRpcError` with `.code == -32603` and `.message == "tool deps not wired"`; fetch not awaited.
    - deps None AND garbage cursor → still -32603 (deps check first).
    - garbage cursor `"not-base64!!!"` → `.code == -32602`, `.message == "invalid cursor"`,
      `.data == {"errors": [{"path": "cursor", "message": ANY_STR}]}` with message `startswith("Invalid cursor format: ")`;
      `conn.fetch.assert_not_awaited()` and `rec.calls == []`.
12. Output: one fully populated row (version=4, is_current=False, deleted_at/expires_at set, indexable=False,
    embedding_status="pending", tags ["x"], type "question", preview "pv", content "ct") → `out.results[0].model_dump()`
    equals the row dict exactly; `out.request_id == "req-1"`.
13. Class attrs: `MemoryListTool.name == "memory_list"`, `required_scope == "memory.read"`,
    `description == TOOL_DESCRIPTIONS["memory_list"]`, `"ALL the listed tags" in MemoryListTool.description`.
14. `_encode_cursor(datetime(2026,1,1,tzinfo=UTC), UUID("33333333-3333-3333-3333-333333333333"))` equals a hardcoded
    base64 string (compute once, paste it as a literal). `_decode_cursor` of that literal returns the exact tuple.
    `_decode_cursor("not-base64!!!")` raises ValueError whose `str()` starts with `"Invalid cursor format: "`.

Run `pytest -q -p no:cacheprovider tests/unit/test_memory_list_sql_exact.py -rxX 2>&1 | tail -15` and paste verbatim.
If any assertion I specified doesn't match actual (correct) behaviour, show me the actual value instead of guessing.
