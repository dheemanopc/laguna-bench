# T6 — mutation scoring (mutmut 3.8.0, offline, lead venv)

## Targets (only these are mutated)
- `src/mem_mcp/mcp/tools/list.py` — `_encode_cursor`, `_decode_cursor`, `MemoryListTool.__call__`
- `src/mem_mcp/plugins/clients/notices.py` — `_json_default`, `NoticeClientImpl.__init__`, `NoticeClientImpl.queue`
- `src/mem_mcp/plugins/notice_delivery.py` — `_render`, `RenderedNotice.__init__`, `RenderedNotice.to_dict`, `deliver_pending`

321 mutants total at base 10fd348.

## Command
Scorer (does everything: violation check, green check, mutmut):

    ~/laguna-bench/bin/t6_score.sh <executor_run_dir> <outdir>

- exits 2 if anything outside new test files changed (src/, alembic/, existing tests, pyproject) vs `~/laguna-bench/wt/base-T6`
- exits 4 if the new test files are not green on a fresh DB
- otherwise runs `~/laguna-bench/bin/t6_mutmut.sh <run_dir> <outdir>/mutmut <new test files>`

`t6_mutmut.sh` copies the tree, writes this `setup.cfg` (pyproject has no [tool.mutmut], so mutmut reads setup.cfg), clones a fresh DB from `bench_tpl`, runs `mutmut run` then `mutmut results --all true`:

    [mutmut]
    source_paths=
        src/
    only_mutate=
        src/mem_mcp/plugins/notice_delivery.py
        src/mem_mcp/plugins/clients/notices.py
        src/mem_mcp/mcp/tools/list.py
    pytest_add_cli_args_test_selection=
        tests/unit/test_notice_delivery.py
        tests/unit/test_notice_client_serialization.py
        tests/unit/test_tools_list.py
        tests/unit/test_search_preview_lenient.py
        tests/unit/test_embedding_status_select.py
        <executor's new test files>
    pytest_add_cli_args=
        -p
        no:cacheprovider
        -q

Env: `MEM_MCP_TEST_DSN`/`MEM_MCP_DB_MAINT_DSN` for the fresh DB; `PYTHONPATH` unset (mutmut puts `mutants/src` first);
AWS env neutralised as for pytest. Kill rate = killed / all mutants (no-tests and survived count as not killed).
`summary.txt` prints a WARNING if any mutant is "not checked" (bad selection / red clean run) — such a score is invalid.

## Runtime (12-core laptop)
- floor (existing tests only): 6–7 s
- with a DB-backed 4-test calibration file: 13–15 s (whole scorer incl. green check ≈ 15 s)
Expect < 2 min even for a large executor suite; hard timeout in the script is 25 min.

## Reference numbers
| test selection | killed / 321 | kill rate |
|---|---|---|
| existing suite for these modules (FLOOR) | 88 | **27.4%** |
| only the tests the original commits added (1aee8ca test_notice_client_serialization.py + 0136429's two tag tests in test_tools_list.py) | 40 | 12.5% |
| floor + author calibration file `reference_tests/tests/integration/test_t6_reference_list_notices.py` (≈30 min of work, 3 tests + 1 strict xfail) | 202 | **62.9%** |

Floor breakdown: deliver_pending / RenderedNotice have **no** covering tests (63 "no tests"); MemoryListTool.__call__ 46/187 killed.
Many of the ~119 survivors at 62.9% are equivalent or near-equivalent (log/audit strings, cursor code made unreachable by the bug below).

## Real bugs present at base (for crediting "bugs found"; do NOT give to executors)
1. **memory_list pagination is broken**: passing any `cursor` crashes — `_decode_cursor` returns the ISO *string* and it is bound
   as a query parameter compared against a timestamptz column → asyncpg `DataError` (surfaces as an internal error, not -32602).
2. **memory_list skips one row per page**: `next_cursor` is built from the overflow row (`rows[limit]`) and the next page uses a strict
   `<`/`>` keyset predicate, so that row is never returned (masked today by bug 1).
3. Keyset order mismatch: ORDER BY `created_at DESC, id` (id ascending) but the predicate compares the tuple `(created_at, id) <`,
   so ties on the timestamp page inconsistently.
