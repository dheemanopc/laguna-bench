# 01 · Context: what was evaluated, under which constraints, and how it unfolded

## Goal and decision bar

Anand wants to know whether Poolside's open-weight coding model **Laguna S 2.1** can be self-hosted and shared by a team (100+ people eventually) as the *implementer* in a split workflow:

| Role | Who | Does |
|---|---|---|
| Planner / reviewer | Claude Sonnet (Opus for escalation and final acceptance) | decomposes the feature, reviews every package against the real code |
| Implementer | Laguna S 2.1, self-hosted | writes the code and tests, runs the checks, commits |

The trigger was Claude budget: planning and review stay on Claude, the bulk of the token-heavy implementation moves to a model the team hosts itself.

The decision bar was set on 2026-10-18 and is narrower than "as good as Sonnet". In Anand's words: *"host on a full scale hardware, and open it to the team. As long as it can do faithful implementations, we are good."* Earlier, on the replay design: *"Sonnet can plan. But I need a faithful model for impl."*

"Faithful" is defined operationally (see `02-harness.md`):

- the model's "tests pass" claim matches what the harness gate measures (no `claim_mismatch`);
- edits stay inside the files the task owns;
- no check is weakened (`type: ignore`, `noqa`, skip/xfail, lint or type-config edits).

Correctness is **not** part of the bar. It is expected to come from mandatory Sonnet review. Speed and per-agent cost were demoted to secondary metrics, on the argument that team-level concurrency amortises the GPU bill.

## Constraints

| Constraint | Source | Consequence |
|---|---|---|
| Licence scope: Laguna, Gemma 4 (Apache-2.0) and Meta Llama only | D29 (2026-10-16) | Mistral/Devstral excluded on licence; Nemotron Puzzle excluded ("trained from qwen data", like Qwen). Both had already been tried as side experiments (T4-D1 failed 19/25 plus 21 new full-suite failures). |
| No hosted APIs for organisation code | Anand, 2026-10-17: *"We cannot use hosted in org. They don't have privacy agreement."* | An in-flight OpenRouter replay was stopped immediately. Self-hosting is the only route for real code. |
| OpenRouter allowed for **capability tests only**, on the open-source repo mem-mcp | Anand, 2026-10-18: *"This code is opensource"* | Run OR-1 used it, and only for that. |
| No credentials leave the laptop | guardrail in the harness | The API key was read from a file at call time, never logged, and shredded after the run. Bench sessions run with empty AWS config and a scrubbed environment. |
| Budget caps | D25, D32 | Cap was $120, later raised to $150. Dead-man shutdown timers on every instance. |
| Test codebase | all runs | mem-mcp ("Memsys"): Python 3.12, FastAPI, asyncpg, Postgres 16 with pgvector, Alembic, a Next.js web app. Baseline `main` is not green (32 known-red tests, D7). |

Whether the Laguna licence permits internal use by 100+ people has not been legally cleared; it is open question Q7 in `07-plan-forward.md`.

## Chronology

| Date (2026) | Run IDs | What was tested | Outcome |
|---|---|---|---|
| Oct 15-16 | T1-T6 (arms B, A, H, S) | Six bench tasks (admin tools, root-cause bug, authz fix, long-context feature, OCC concurrency, test writing). Laguna S 2.1 **FP8, TP2** on g7e.12xlarge, Opus master, Laguna / Haiku / Sonnet executors. | Laguna 4/11 valid runs passed vs Sonnet 4/5: **rejected as a drop-in executor** (REPORT.md). 5 of 7 failures hit the 120-min cap. |
| Oct 16 | T4-X1, T5-X1, T6-X1 | Laguna **XS** on one GPU (D23-D24). | T4 23/25, T5 pass; T6 killed by Anand. |
| Oct 16 | F1-1 | First real feature (trackable mindmap nodes), Opus owner, Sonnet DA, 2 XS developers. | Opus: ACCEPT WITH FIXES; caught two business contradictions Sonnet missed. |
| Oct 16 | T4-D1/Q1/P1 | Devstral, Qwen3.6, Nemotron Puzzle as comparison models. | Dropped on licence (D29). |
| Oct 16 | T4-F1, F2-1..F2-3 | Laguna S 2.1 **GGUF Q5_K_M** on one RTX PRO 6000 (g7e.8xlarge spot), llama.cpp fork with DFlash speculative decoding. Feature F2 (team workflows + board). | F2-2: 87 min, zero tests, REJECT. F2-3 (Opus architect gates): REJECT, cap hit after WP2 (D54). |
| Oct 17 | F2-4 | **GGUF Q4_K_M**, new `f2x` harness, g7e.2xlarge spot. | 2 of 27 tasks in 6h25m; ~$17.85. Anand's verdict: not worth it for interactive feature work (D58). |
| Oct 17-18 | OR-1 | **OpenRouter, Poolside endpoint (fp4)**, replay of F2-4 tasks. | WP1-T1 pass in 8.6 min ($0.03); WP1-T3 added `type: ignore` (first faithfulness concern). |
| Oct 18 | BF attempt 1 | g7e.24xlarge spot launched, then terminated at 13:38 IST when Anand went offline. | Root volume kept; weights lost. |
| Oct 18-19 | BF-1..BF-4, PL-G, PL-P, F2-5 | **BF16, vLLM TP4** on g7e.24xlarge spot (4x RTX PRO 6000). Replays, one-shot planning, full build. | Faithful in every valid sample; 5 semantic defects behind green gates; BF-2..4 invalid (tunnel stalls). |
| Oct 19 | F2-6, F2-7 | **Sonnet** and **Haiku** as implementers on the *same* harness and plan, for comparison. | Runs were still in progress when this was written (see below). |

## Key pivots and why

1. **From "replace Sonnet" to "faithful implementer".** The first benchmark (Oct 15-16) asked whether Laguna could replace Sonnet under an Opus master. It failed that rule (36% vs 80% pass rate). But the failures were mostly time-cap and supervision cost, not dishonesty, so the question was rewritten around faithfulness.
2. **Supervision got cheaper, then the model got slower.** F2-3 (all-Opus architect gates) cost ~$30 and ended REJECT; its lessons (D45-D54) produced the `f2x` harness: one persistent Sonnet delivery lead, fresh Laguna session per task, routing in a script. On Q4 that harness still managed only 2 of 27 tasks in 6.5 h. Anand's call, recorded in D58: at ~20-30 min per task against ~5-8 for Sonnet, and about half the dollars per task, Q4 on an RTX PRO 6000 is not worth it for interactive feature work. Untested levers listed: thinking off for simple tasks, HBM GPUs.
3. **Hosted detour and its closure.** Because the self-hosted Q4 was slow, OpenRouter looked attractive (Laguna S 2.1 at roughly 80x cheaper per output token). The privacy constraint killed it for org code; it survived as a capability probe. Note that **OpenRouter's only Poolside provider serves fp4, and no hosted BF16 API exists** (Poolside, Baseten and FriendliAI were checked), so the only way to see BF16 behaviour is to host it.
4. **"I wanted to test fb16."** The fp4 results (type-ignore added) left open whether quantisation caused the weakened check. Anand asked for full precision, which led to the g7e.24xlarge BF16 box. Result: no weakened checks in any valid BF16 sample.
5. **Tunnel failure forced a rule.** Running the harness on the laptop against the GPU box invalidated every parallel BF16 replay. The deployment rule became: agents run next to the GPUs (`06-infra-lessons.md`).
6. **Baselines on the same harness.** To place Laguna on a scale, F2-6 (Sonnet) and F2-7 (Haiku) ran the same plan through the same gates. Ledger snapshots at the time of writing: Sonnet had 30 tasks done and five milestone gates passed after ~73 min, with about $21 of engineer-session cost (API-equivalent). Haiku had 4 done, 2 failed and a failed WP1 milestone gate after ~47 min. These are partial and should be re-read from the final run records.

## Where it landed (2026-10-19)

- Faithfulness: **PASS** for BF16 in every valid sample. fp4 showed one violation.
- Correctness: needs Sonnet review. 5 authorisation/integrity defects found at the WP1 milestone with all gates green.
- Planning: draft quality only (one-shot design 5.5/10, WP1 plan 6.5/10).
- Economics: the 4-GPU box ran at about 10% of capacity for one user; cost per task only works with shared load.
- Recommendation in the BF16 report: go ahead with a team-shared self-host, with Sonnet reviewing every package and the harness co-located with the GPUs.
