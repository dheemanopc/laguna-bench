# T6 validation — test writing, mutation-scored

Base `10fd348` (main), template `bench_tpl`. No hidden tests; scoring = mutmut kill rate (see mutmut.md).

## Commands
```
~/laguna-bench/bin/t6_mutmut.sh ~/laguna-bench/wt/base-T6 <out>                       # floor
~/laguna-bench/bin/t6_mutmut.sh ~/laguna-bench/wt/base-T6 <out> --only tests/unit/test_notice_client_serialization.py \
   tests/unit/test_tools_list.py::TestMemoryListTool::test_tag_filter_is_and_semantics \
   tests/unit/test_tools_list.py::TestMemoryListTool::test_single_tag_filter_still_works   # original-commit tests
~/laguna-bench/bin/t6_score.sh <run_dir> <out>                                           # scorer
```
## Results
- floor (existing tests for the targets): 88/321 killed = **27.4%** (6–7 s; identical on 2 runs)
- tests added by the original commits (0136429 tag tests + 1aee8ca): 40/321 = 12.5%
- floor + author calibration file (tasks/T6/reference_tests, DB-backed): 202/321 = **62.9%** (13–15 s)
- scorer self-test: base + calibration file → 62.9%; a run dir with a one-line edit to src/ → exit 2 DISQUALIFIED
- base full suite: 18 failed, 1330 passed, 31 skipped, 16 errors → known_red_base.txt (= T5 base)

## (c) leakage
The packet lists the modules and behaviours to cover (from the tool description / module docstrings) and how scoring works,
but not the bugs present at base (cursor pagination crash, skipped overflow row, tie-order mismatch) — finding them is credited separately.

## Review (Opus)
- Leakage: OK — the base bugs (cursor ISO-string crash, skipped overflow row, tie-order mismatch) are not mentioned; the two cited regressions are already-fixed history. Listing "next_cursor and pagination" / "invalid cursors → -32602" as behaviours to cover is normal scope, not a leak.
- Fairness: OK — no hidden tests; scoring method, target modules, isolation and xfail(strict) rules are stated.
- Ambiguity: none. No edits.
