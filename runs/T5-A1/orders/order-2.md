# Work order 2 — verify order 1 and one small fix

The order-1 code review looks good. Two things now:

## A. Small fix
`src/mem_mcp/web/handlers/memories.py::_jsonrpc_to_http` maps every -32000 to 403. An update conflict is not an
authz failure: when `exc.code == -32000` and `exc.data` is a dict with `data["code"] == "update_conflict"`, map
to HTTP **409**. Leave all other mappings unchanged.

## B. Run everything (this is required — you must actually execute the commands)
You have a Bash tool; please use it (if a command is refused, retry with a plain command such as
`pytest -q -p no:cacheprovider tests/unit/test_tools_update.py`, and report the exact refusal text if it still fails).

1. `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/integration/test_update_concurrency.py`
   — fix any failure in the NEW tests or in the implementation (do not edit existing tests).
2. Prove the new tests catch the bugs: `git stash push src/` (keep the new test file), run
   `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py`, record which tests fail,
   then `git stash pop`. Expected: tag-add/remove, decision fork, superseded-id and same-expected-revision tests
   fail (revision-related ones may fail on attribute errors — that's fine). Report the results.
3. Baseline vs. now for the full suite: `git stash push src/ tests/integration/test_update_concurrency.py`
   (note: an untracked file needs `-u`; alternatively move it aside temporarily), run
   `pytest -q -p no:cacheprovider tests/unit tests/integration 2>&1 | tail -40`, save the list of failing test
   ids; restore; rerun with the change; report both failing sets and the diff (must be no new failures).
   Also run `pytest -q -p no:cacheprovider` (whole suite incl. tests/security) once with the change and compare
   in the same way if time permits.
4. `ruff check src tests` and `ruff format --check` on touched files, and `mypy` — fix issues in touched files.
5. Run the new concurrency test file 3 times in a row to check it is not flaky.

Report exact commands and pass/fail counts.
