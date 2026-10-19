# Work order 3 — baseline comparison without git stash

Accepted: `MemoryUpdateOutput.revision` default `""` (backward compat for existing constructors) — keep it.
Do NOT change any source or test files in this order; this is verification only.

`git stash` is refused, so build a pristine copy of the original code OUTSIDE the repo instead:

1. `mkdir -p /tmp/t5-baseline && git -C ~/laguna-bench/runs/T5-A1/repo archive HEAD | tar -x -C /tmp/t5-baseline`
   (if /tmp is refused, use any scratch dir outside the repo you are allowed to write.)
2. Copy the new test file into the baseline copy:
   `cp tests/integration/test_update_concurrency.py /tmp/t5-baseline/tests/integration/`
3. Run the new tests against the ORIGINAL source, making sure the baseline `src/` is what gets imported:
   `cd /tmp/t5-baseline && PYTHONPATH=/tmp/t5-baseline/src python -c "import mem_mcp; print(mem_mcp.__file__)"`
   (must print the baseline path), then
   `cd /tmp/t5-baseline && PYTHONPATH=/tmp/t5-baseline/src pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py`
   Report which tests fail and why (one line each). Expected: the concurrency/fork/superseded/revision tests fail.
4. Baseline full suite: `cd /tmp/t5-baseline && PYTHONPATH=/tmp/t5-baseline/src pytest -q -p no:cacheprovider -rfE 2>&1 | grep -E "^(FAILED|ERROR)" | sort > /tmp/t5-base.txt`
   (exclude the copied new test file from this run with `--deselect`/`--ignore=tests/integration/test_update_concurrency.py`).
   Then in the real repo: `pytest -q -p no:cacheprovider -rfE --ignore=tests/integration/test_update_concurrency.py 2>&1 | grep -E "^(FAILED|ERROR)" | sort > /tmp/t5-new.txt`
   and `diff /tmp/t5-base.txt /tmp/t5-new.txt`. Report the counts and the full diff output. Note the shared
   test DB may make some fixture-collision tests nondeterministic — if a test differs, rerun just that test in
   both trees once to classify it.
5. Clean up `/tmp/t5-baseline` afterwards.
