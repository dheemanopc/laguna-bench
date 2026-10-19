# Work order 7 — invalid cursors through the tool (TESTS ONLY, small)

Keep tool output short (`-q`, `| tail -20`). Do only this.

Add to `tests/integration/test_memory_list_pagination_db.py` one parametrized async test
`test_invalid_cursor_rejected(pg_pool, raw)`. Setup: tenant via `_setup_tenant_and_team`, insert one
memory, call `MemoryListTool()(ctx, MemoryListInput(cursor=cursor))` in `pytest.raises(JsonRpcError)`
(`from mem_mcp.mcp.errors import JsonRpcError`), then assert
`exc.value.code == -32602`, `exc.value.message == "invalid cursor"`,
`exc.value.data["errors"][0]["path"] == "cursor"`,
`exc.value.data["errors"][0]["message"].startswith("Invalid cursor format: ")`. Cleanup in finally.

`cursor` = the raw str if the param is a `str`, else `base64.urlsafe_b64encode(raw).decode()` for bytes.
Cases (use `pytest.param(..., id=...)`):
- `garbage`: `"not-base64!!!"` (str)
- `not_json`: `b"not json"`
- `empty_list`: `b"[]"`
- `one_elem`: `b'["x"]'`
- `non_utf8`: `b"\xff\xfe"`
- `dict`: `b"{}"`
- `int`: `b"5"`
- `null`: `b"null"`
- `string`: `b'"s"'`
- `bad_uuid`: `json.dumps(["2026-01-01T00:00:00+00:00", "not-a-uuid"]).encode()`
- `bad_ts`: `json.dumps(["yesterday", "00000000-0000-0000-0000-000000000001"]).encode()`

Run it. For every case that does NOT pass, add to that `pytest.param` the mark
`pytest.mark.xfail(strict=True, raises=<exact exception class you observed>, reason="BUG: <case> cursor raises <Exc> instead of JSON-RPC -32602")`.
Note: `"string"` decodes to `"s"`; `data[0]` = `"s"`, `data[1]` → IndexError → caught; it may pass. Let the run decide.

Run:
`pytest -q -p no:cacheprovider tests/integration/test_memory_list_pagination_db.py -rxX 2>&1 | tail -25`
and paste verbatim, plus one line per xfail case: case id → observed exception class + message.
