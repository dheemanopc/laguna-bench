# Work order 4 — Last fixes + the two missing pieces of evidence

## 1. Small test fix (`tests/integration/test_update_concurrency.py::TestConcurrentMixedOperations::test_concurrent_mixed_on_decision`)
- The final-state check reads `memory_get(memory_id)` — that's v1, which is superseded if the content update won. Instead read the **current** row of the chain: if the content update succeeded, `memory_get(<its output id>)`; otherwise `memory_get(memory_id)`. Assert every tag from a successful tag-add call (`inp` tag, i.e. the tag that call added) is present on that current row.
- Assert the content update itself succeeded (it is the only content change on a current decision, so it can never be refused — tag adds may be refused only if they ran after the version bump). Remove the vacuous asserts (`len(conflicts) >= 0`) and the misleading "Exactly 2 should succeed" comment.
- Also assert every refused call is a tag-add with `data["current_id"] == str(content_output.id)`.

## 2. Prove the tests fail against the original code (stash was unavailable — use this instead)
```
S=<your scratch dir>; mkdir -p $S/backup
cp src/mem_mcp/mcp/tools/update.py src/mem_mcp/mcp/tools/get.py src/mem_mcp/memory/versioning.py src/mem_mcp/mcp/tool_descriptions.py $S/backup/
git show HEAD:src/mem_mcp/mcp/tools/update.py > src/mem_mcp/mcp/tools/update.py
git show HEAD:src/mem_mcp/mcp/tools/get.py > src/mem_mcp/mcp/tools/get.py
git show HEAD:src/mem_mcp/memory/versioning.py > src/mem_mcp/memory/versioning.py
git show HEAD:src/mem_mcp/mcp/tool_descriptions.py > src/mem_mcp/mcp/tool_descriptions.py
```
(If `git show` is blocked too, use `git checkout HEAD -- <those 4 files>` after the backup.)
Then run `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py -rfE 2>&1 | tail -40` and report, verbatim, the FAILED lines. Note: the test module imports `compute_revision`/`expected_revision`-using code — if the whole module fails at import against old code, temporarily create a throwaway copy in your scratch dir (NOT in the repo) of just the concurrent tag-add, tag-remove and versioned-fork tests with no reference to `revision`/`expected_revision`, run it via `pytest <scratch path> --rootdir=. -c pyproject.toml` (or copy it into `tests/integration/_tmp_old_check.py` and delete it afterwards), and report which of those fail against the old code and with what assertion.

Then restore: `cp $S/backup/* ` back to the right paths (update.py & get.py → src/mem_mcp/mcp/tools/, versioning.py → src/mem_mcp/memory/, tool_descriptions.py → src/mem_mcp/mcp/). Verify with `git diff --stat` that all 4 src files show your changes again, and that no temp test file remains in the repo.

## 3. Full suite before/after comparison
While the original src is in place (step 2, before restoring), also run the full suite:
`pytest -q -p no:cacheprovider -rfE 2>&1 | grep -E '^(FAILED|ERROR)' | sed 's/ - .*//' | sort > $S/before.txt; tail -1` (keep the summary line).
After restoring: same into `$S/after.txt`. Report both summary lines and the verbatim output of `comm -13 $S/before.txt $S/after.txt` (failures present only after your change). Exclude your own new test files from the comparison. If anything is in that list, investigate and tell me whether it's caused by your change; if flaky, rerun that test individually on both versions and report.

## 4. Final
Run `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_web_memories_handler.py tests/unit/test_update_revision.py tests/integration/test_update_concurrency.py` and `ruff check src tests` and report. Show `git status`.
