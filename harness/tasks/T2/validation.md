# T2 validation — memory_not_accessible when citing my own memory (references validator)

Base `483763d` · solution `8126500` · DB template `bench_tpl_t2` (alembic upgrade head run on the fresh clone before tests)

## (a) hidden tests fail at base, pass at solution (fresh DB each run)

```
~/laguna-bench/bin/run_hidden.sh T2 ~/laguna-bench/wt/base-T2 bench_tpl_t2 <db> --migrate
~/laguna-bench/bin/run_hidden.sh T2 ~/laguna-bench/wt/sol-T2  bench_tpl_t2 <db> --migrate
# end-to-end scorer self-test (copies tree, hidden+visible, full suite, new-failure diff):
~/laguna-bench/bin/score_task.sh T2 ~/laguna-bench/wt/sol-T2  <out>   -> RESULT: PASS
~/laguna-bench/bin/score_task.sh T2 ~/laguna-bench/wt/base-T2 <out>   -> RESULT: FAIL
```
- base: hidden: 5 failed, 16 passed; visible repro: 1 failed (PluginValidationError memory_not_accessible)
- solution: hidden 21 passed + visible 1 passed
- hidden test ids: 21 (FAIL_TO_PASS 5, PASS_TO_PASS 16) — lists in meta.json

## (b) rest of the suite

```
~/laguna-bench/bin/run_tests.sh ~/laguna-bench/wt/base-T2 bench_tpl_t2 <db> -- -rfE tests      # twice, identical red sets
FULL=1 ~/laguna-bench/bin/run_hidden.sh T2 ~/laguna-bench/wt/sol-T2 bench_tpl_t2 <db> --migrate
```
- base full suite: 34 failed, 1033 passed, 31 skipped, 16 errors (48 red ids) → `known_red_base.txt`
- solution full suite (+hidden overlay): 34 failed, 1046 passed, 31 skipped, 16 errors — 0 new

## (d) solution size
+150 / -66 non-test lines in 4 files (migration 0035 87, references.py 103, refs_in 18, refs_out 8)

## (c) why the packet does not leak the solution
Packet = symptom + reproduction conditions + expected behaviour + constraint not to widen slug pre-resolution gates (needed so P2P carve-out locks are fair). It does not name user_effective_team_access, the same-tenant rule, the validator functions, or the sibling sites (removed an earlier draft sentence that enumerated them). Visible test is author-rewritten from the commit test without "UEA"/"same-tenant escape"/"post_fix" vocabulary and without the UEA-emptiness guard.

## Review (Opus)
- Leakage: MINOR — "i.e. with what `memory_get` / the RLS `memories_select` policy lets the caller see" pointed straight at the policy whose same-tenant clause is the fix. Cut to "i.e. with what `memory_get` lets the caller see." Root cause (UEA-only gate, UEA not populated by raw-SQL provisioning) is otherwise not named; the raw-SQL provisioning detail is also visible in the repro, so it is symptom-level.
- Fairness: OK — hidden tests import only functions/exceptions that already exist at base (`resolve_reference_target`, `check_hard_delete_with_filtered_citers`, …); "every such place must be fixed" + "act on, via the references machinery" covers the hard-delete citer site; slug carve-outs are stated.
- Ambiguity: none blocking. Shared CONVENTIONS.md fix: `memory_not_accessible` is -32602 in code (was listed as -32000).
