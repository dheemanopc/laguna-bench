# Laguna Bench — final report (2026-10-15/16)

Published page: https://claude.ai/artifact/7rVbsmt1E4RAzDznULF823 (private until shared)

## Decision under the plan's rule: REJECT as a drop-in executor
- Pass rate on the 5 tasks Sonnet also ran: Laguna 4/11 valid runs (36%) vs Sonnet 4/5 (80%) → 45% of Sonnet's rate (rule needs ≥ 80%).
- Mandatory tasks: T3 2/2 PASS; T1 0/2 (32/35, 27/35, both capped) while Sonnet passed T1 in 9 min.
- Blind design review: Laguna 4.0 avg (9 runs; T6-B1 excluded, contaminated by an orphan executor) vs Sonnet 5 (T4 only). No test tampering.
- 5 of 7 failing Laguna runs hit the 120-min cap (2 with no Opus review at all). Every Laguna run that finished inside the cap passed, except the planner's T4 spec error.

## Results by task (hidden tests)
| Task | Laguna (valid) | Haiku 4.5 | Sonnet 5.5 |
|---|---|---|---|
| T1 admin user tools | 0/2 (32/35, 27/35 capped) | — | PASS 35/35 |
| T2 references root-cause bug | 3/3 PASS | 2/2 PASS | PASS |
| T3 member-tool authz | 2/2 PASS | — | — |
| T4 mindmap branch status | 23/25 ×2 (master-attributed) | 23/25 ×2 | 23/25 |
| T5 lost updates (OCC) | 1/2 (15/15; 12/15 capped) | — | PASS |
| T6 test writing (mutation) | 0/2 gate (best 86.9% unofficial) | — | PASS 95.0% |
Laguna solo on T4 (raw packet, no Opus): 19/25 — got the whose-turn business rule right (every Opus-led run got it wrong), missed 6 explicit spec details.
Degraded/invalid runs (harness or network) are kept in runs/_invalid and excluded. Per-run metrics: results/runs.csv / runs.md.

## Supervision (Opus correction effort)
| Executor | Runs | Median rounds | Median follow-up words | Median wall |
|---|---|---|---|---|
| Sonnet 5.5 | 5 | 3 | 564 | 9 min |
| Laguna S 2.1 | 13 | 3 | 841 | 115 min (shared GPU; 33 min alone on T2) |
| Haiku 4.5 | 4 | 5.5 | 1,575 | 19 min |

## Infra (g7e.12xlarge, FP8, TP2, vLLM 0.25.1)
- KV 1,478,805 tokens (hybrid SWA allocation correct, ~12 KB/token/GPU); 1M max-len: 1,557,823 tokens.
- 300k prompt: 38 s cold / 0.79 s warm. 892k prompt: 245 s cold / 2.1 s warm.
- RAM KV offload (300 GiB native): evicted 128k agent resumes in 1.45 s vs 10.62 s re-prefill; GPU KV unchanged.
- Capacity (32k): per-agent 119→77→57→32→18→10.5 tok/s at 1/2/4/8/16/32 agents; aggregate 96→315. Max sustainable at 128k (≥20 tok/s/agent): 4. Live agent traffic: 180–195 tok/s aggregate, 98% prefix-cache hits after the shim.
- Tuning: DFlash (needs --disable-custom-all-reduce under TP2) and max-num-batched-tokens 32768 both rejected (no aggregate gain at c8×128k, cost KV).

## Cost per task
Sonnet executor ≈ $1.85 (list). Laguna at ~4 tasks/box-hour: on-demand $2.07 (100% use) / $4.14 (50%); spot ≈ $1.58; EC2 Instance SP 1-yr $5.22/h → $1.31; 3-yr $3.58/h → $0.90. Laguna only wins as a well-utilised shared service.

## Harness lessons (details: logs/harness_events.log, docs/JOURNAL.md)
system-message shim for prefix caching; vLLM native /v1/messages (signed thinking); interactive sessions for Remote Control; deny plan/worktree tools; executor timeout = run budget + reap executors on cap; widen executor allowlist; SSH compression over hotspot.

## Next tests
Checkpoint rule + wider allowlist re-run; Laguna tree under Opus with an abstract brief and a Laguna technical reviewer; scheduling gateway (5–7 decoding agents, role priorities, RAM offload) via traffic replay; NVFP4 on one GPU.

## Caveats
Small samples; shared GPU + mobile hotspot (≈30 min degraded); FP8 only; capped-run review diffs may include post-cap orphan edits; one codebase.

## Resources
AWS ≈ $89 (10.6 h) of $120; instance i-038bcc80d18257689 STOPPED with weights kept (≈ $2.30/day disk). Laptop data 4.84 GB down / 2.44 GB up. Toolkit: bin/lb, docs/RUNBOOK.md.
