# T4 validation — Mind-map branch status + cheap resume reads (mindmap_resolve, since/include/depth)

Base `1b9ae6c` · solution `8bb3100` · DB template `bench_tpl_t4` (alembic upgrade head run on the fresh clone before tests)

## (a) hidden tests fail at base, pass at solution (fresh DB each run)

```
~/laguna-bench/bin/run_hidden.sh T4 ~/laguna-bench/wt/base-T4 bench_tpl_t4 <db> --migrate
~/laguna-bench/bin/run_hidden.sh T4 ~/laguna-bench/wt/sol-T4  bench_tpl_t4 <db> --migrate
# end-to-end scorer self-test (copies tree, hidden+visible, full suite, new-failure diff):
~/laguna-bench/bin/score_task.sh T4 ~/laguna-bench/wt/sol-T4  <out>   -> RESULT: PASS
~/laguna-bench/bin/score_task.sh T4 ~/laguna-bench/wt/base-T4 <out>   -> RESULT: FAIL
```
- base: 24 failed, 1 passed (P2P: test_open_loops_are_whose_turn_only)
- solution: 25 passed
- hidden test ids: 25 (FAIL_TO_PASS 24, PASS_TO_PASS 1) — lists in meta.json

## (b) rest of the suite

```
~/laguna-bench/bin/run_tests.sh ~/laguna-bench/wt/base-T4 bench_tpl_t4 <db> -- -rfE tests      # twice, identical red sets
FULL=1 ~/laguna-bench/bin/run_hidden.sh T4 ~/laguna-bench/wt/sol-T4 bench_tpl_t4 <db> --migrate
```
- base full suite: 35 failed, 1221 passed, 31 skipped, 16 errors (49 red ids) → `known_red_base.txt`
- solution full suite (+hidden overlay): 35 failed, 1270 passed, 31 skipped, 16 errors — 0 new

## (d) solution size
full commit +1068 / -17 non-test lines in 10 files; in-scope part ≈ 500 (migration 146 [part out of scope], mindmap_get +113, mindmap_resolve 126, service ≈ +150 of 264, descriptions/main ≈ 20). Out-of-scope files: mindmap_answer 191, mindmap_queue 135, close +19, write_node +30.

## (c) why the packet does not leak the solution
Packet specifies the public interface (tool/module/class names, input fields with ranges/defaults, output field names, 200-char summary rule, cursor semantics). Doc-only clauses are deliberately NOT restated: which edge kind each disposition writes (design doc reference-kind vocabulary: resolves-under / dropped-under), archived = no-reopen ("respect the lifecycle rules of the design doc"), and the whose-turn definition of open loops. Hidden tests are author-written black-box tests; none of the commit's white-box helper names (_maybe_truncate, fetch_members, set_node_status) are required.

## Review (Opus)
- Leakage: OK — edge kinds, no-reopen and whose-turn are left to the design doc (doc lists `resolves-under`/`dropped-under` in its reference-kind vocabulary and the no-reopen lifecycle rule).
- Fairness: OK — all imported names/fields (MindmapResolve{Tool,Input,Output}, since/include/depth, cursor, resolved[], truncated, status) are specified with ranges/defaults; 200-char + "…" rule and "no change → no nodes, same cursor" are explicit.
- Ambiguity: archived-map refusal must be -32602. CONVENTIONS.md previously listed `map_not_live` under -32000 (contradicting the codebase, where write_node/close raise -32602 + data.code=map_not_live), which could have steered an agent to the wrong code. Fixed in CONVENTIONS.md; no packet edit.
