# T5 validation — No lost updates: optimistic concurrency + serialized memory_update

Base `10fd348` · solution `author reference.patch (wt/sol-T5)` · DB template `bench_tpl`

## (a) hidden tests fail at base, pass at solution (fresh DB each run)

```
~/laguna-bench/bin/run_hidden.sh T5 ~/laguna-bench/wt/base-T5 bench_tpl <db> 
~/laguna-bench/bin/run_hidden.sh T5 ~/laguna-bench/wt/sol-T5  bench_tpl <db> 
# end-to-end scorer self-test (copies tree, hidden+visible, full suite, new-failure diff):
~/laguna-bench/bin/score_task.sh T5 ~/laguna-bench/wt/sol-T5  <out>   -> RESULT: PASS
~/laguna-bench/bin/score_task.sh T5 ~/laguna-bench/wt/base-T5 <out>   -> RESULT: FAIL
```
- base: 13 failed, 2 passed — stable over 11 runs (concurrency tests fail by real races: lost tag adds, 6/6 forked versions, 6/6 winners)
- solution: 15 passed — 24/24 runs incl. 12 under 4-way parallel load
- hidden test ids: 15 (FAIL_TO_PASS 13, PASS_TO_PASS 2) — lists in meta.json

## (b) rest of the suite

```
~/laguna-bench/bin/run_tests.sh ~/laguna-bench/wt/base-T5 bench_tpl <db> -- -rfE tests      # twice, identical red sets
FULL=1 ~/laguna-bench/bin/run_hidden.sh T5 ~/laguna-bench/wt/sol-T5 bench_tpl <db> 
```
- base full suite: 18 failed, 1330 passed, 31 skipped, 16 errors (32 red ids = known-red-online.txt) → `known_red_base.txt`
- solution full suite (+hidden overlay): 18 failed, 1345 passed, 31 skipped, 16 errors — 0 new

## (d) solution size
reference.patch: +90 / -10 in 4 files (update.py, get.py, versioning.py, tool_descriptions.py); no migration

## (c) why the packet does not leak the solution
Packet gives the observable contract (revision field names, expected_revision, -32000 + data.code update_conflict + current_revision/current_id, exactly-one-winner and no-fork semantics) and requires DB-level correctness, but not the mechanism (row lock vs conditional UPDATE vs revision column), the token derivation, or code. Mutation check: reference minus FOR UPDATE fails 5 concurrency tests 5/5 runs, so a check-then-act implementation is caught.

## Review (Opus)
- Leakage: OK — observable contract only; mechanism options listed generically. ("merges in Python against a row it read earlier" names the lost-update cause but that is symptom-level for a concurrency task.)
- Fairness: GAPS — hidden unit test `test_memory_record_exposes_revision` constructs `MemoryRecord` WITHOUT a revision argument and requires `model_dump()["revision"]` to be a non-empty str. A natural design (new `revision` column + required/optional-None field, which the packet's "migration is fine" invites) fails it.
  - Edit: added to the `memory_get` bullet: "`MemoryRecord` must stay constructible from its existing fields alone (no new required constructor argument), and a record built that way must still report a non-empty string `revision` (including in `model_dump()`)." This constrains the token to be derived from existing fields without naming which.
- Ambiguity: none else (conflict code/data keys, -32602 for not-found, exactly-one-winner semantics stated).
