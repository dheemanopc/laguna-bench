EVENT wp_plans_review (round 2). Package plans to review: docs/feature/wp0.md, docs/feature/wp1.md, docs/feature/wp2.md, docs/feature/wp3.md, docs/feature/wp4.md, docs/feature/wp5.md. For EACH document spawn one Agent subagent
(all in one message so they run in parallel) with this brief: "Review <doc> in ~/laguna-bench/runs/F2-4/repo against docs/feature/00-goal.md:
design consistent with the goal and the codebase; tasks small (≤~3 source files + test, ≤~400 lines), every promised
interface delivered by some task, files owned by one task, deps correct, tests meaningful. Read code only to confirm a
doubt. Return 'VERDICT: APPROVE|REVISE' and at most 5 one-line findings." Then combine.
Reply json: {"verdicts":{"<WPid>":{"verdict":"APPROVE|REVISE","findings":["..."]}}}