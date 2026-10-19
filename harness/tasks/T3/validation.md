# T3 validation — Gate team member-management tools on team.manage_members

Base `67b15b7` · solution `a68387f` · DB template `bench_tpl`

## (a) hidden tests fail at base, pass at solution (fresh DB each run)

```
~/laguna-bench/bin/run_hidden.sh T3 ~/laguna-bench/wt/base-T3 bench_tpl <db> 
~/laguna-bench/bin/run_hidden.sh T3 ~/laguna-bench/wt/sol-T3  bench_tpl <db> 
# end-to-end scorer self-test (copies tree, hidden+visible, full suite, new-failure diff):
~/laguna-bench/bin/score_task.sh T3 ~/laguna-bench/wt/sol-T3  <out>   -> RESULT: PASS
~/laguna-bench/bin/score_task.sh T3 ~/laguna-bench/wt/base-T3 <out>   -> RESULT: FAIL
```
- base: 15 failed, 4 passed
- solution: 19 passed
- hidden test ids: 19 (FAIL_TO_PASS 15, PASS_TO_PASS 4) — lists in meta.json

## (b) rest of the suite

```
~/laguna-bench/bin/run_tests.sh ~/laguna-bench/wt/base-T3 bench_tpl <db> -- -rfE tests      # twice, identical red sets
FULL=1 ~/laguna-bench/bin/run_hidden.sh T3 ~/laguna-bench/wt/sol-T3 bench_tpl <db> 
```
- base full suite: 34 failed, 1295 passed, 31 skipped, 16 errors (48 red ids) → `known_red_base.txt`
- solution full suite (+hidden overlay): 34 failed, 1314 passed, 31 skipped, 16 errors — 0 new

## (d) solution size
+138 / -1 non-test lines in 5 files (teams/authz.py 75, permissions 25, three tools 39)

## (c) why the packet does not leak the solution
Packet is a security report: exploit steps, required permission name, error-data convention, no-oracle and self-removal rules, and the role→permission matrix stated as a product decision (the hidden unit test pins it, so it must be specified). It does not say where to put the check, that ROLE_PERMISSIONS lacks owner (it says the matrix "only knows the legacy admin/member"), or how to order the gate vs email resolution beyond the behavioural oracle rule.

## Review (Opus)
- Leakage: OK — security report + required permission + role matrix as product decision (required by the pinned unit test). "only knows the legacy admin/member" hints owner is missing, but that is needed for the matrix spec.
- Fairness: OK — tool class/input names pre-exist; permission names exist at base; missing_permission data, no-oracle, self-removal, owner-works and "exactly the catalog roles + system roles" all stated.
- Ambiguity: none found. No edits.
