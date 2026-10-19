# T1 validation — Admin user lookup over MCP (memsys_admin_find_user / memsys_admin_get_user)

Base `2c6b590` · solution `67b15b7` · DB template `bench_tpl`

## (a) hidden tests fail at base, pass at solution (fresh DB each run)

```
~/laguna-bench/bin/run_hidden.sh T1 ~/laguna-bench/wt/base-T1 bench_tpl <db> 
~/laguna-bench/bin/run_hidden.sh T1 ~/laguna-bench/wt/sol-T1  bench_tpl <db> 
# end-to-end scorer self-test (copies tree, hidden+visible, full suite, new-failure diff):
~/laguna-bench/bin/score_task.sh T1 ~/laguna-bench/wt/sol-T1  <out>   -> RESULT: PASS
~/laguna-bench/bin/score_task.sh T1 ~/laguna-bench/wt/base-T1 <out>   -> RESULT: FAIL
```
- base: 3 errors (collection: ModuleNotFoundError mem_mcp.admin) → all 35 hidden tests fail
- solution: 35 passed
- hidden test ids: 35 (FAIL_TO_PASS 35, PASS_TO_PASS 0) — lists in meta.json

## (b) rest of the suite

```
~/laguna-bench/bin/run_tests.sh ~/laguna-bench/wt/base-T1 bench_tpl <db> -- -rfE tests      # twice, identical red sets
FULL=1 ~/laguna-bench/bin/run_hidden.sh T1 ~/laguna-bench/wt/sol-T1 bench_tpl <db> 
```
- base full suite: 34 failed, 1260 passed, 31 skipped, 16 errors (48 unique red ids) → `known_red_base.txt`
- solution full suite (+hidden overlay): 34 failed, 1295 passed, 31 skipped, 16 errors — red set identical to base (0 new)

## (d) solution size
+550 / -0 non-test lines in 10 files (admin/ package 246, _admin_base 145, two tools 118, descriptions 22, main/audit/lint 19)

## (c) why the packet does not leak the solution
Packet gives the interface the hidden tests import (module paths, class/function names, field names, -32602 / missing_permission data, audit fields) — unavoidable for new-module tests, and equivalent to an API spec. It does not give code, SQL, the gate implementation, or the rollback-surviving audit technique (only the behaviour "denied call leaves exactly one denied row"). Test names/assertion code are not quoted.

## Review (Opus)
- Leakage: OK — interface spec only (names/fields/codes the hidden tests import); no code, SQL or the fresh-transaction denial-audit technique.
- Fairness: GAPS (minor) — hidden tests read audit rows by the *caller's* tenant_id; packet did not say whose tenant the audit row is attributed to (get_user could plausibly audit the target tenant).
  - Edit: packet §2 "Every call is audited" now says the row is attributed to the caller (`tenant_id`/`identity_id` from the tool context, not the looked-up user).
- Ambiguity: none else found (escape/clamp helpers, -32602 mapping, missing_permission data, exactly-one row all stated).
- Shared edit (CONVENTIONS.md): error-model bullet wrongly listed `memory_not_accessible`/`map_not_live` as -32000; the codebase raises both as -32602. Corrected (affects T2/T4).
