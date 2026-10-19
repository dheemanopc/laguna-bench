# 05 · Economics

## 1. What tonight's BF16 box actually cost (2026-10-18/19)

| Item | Value |
|---|---|
| Hardware | g7e.24xlarge spot (4× RTX PRO 6000 96 GB), about $5.92/hr |
| Lifetime | about 293 min: 14 boot, 272 serving, 7 idle after done |
| Busy (≥1 request) | 225 min; 68 min fully idle (about $6.70) |
| Average concurrency | 1.8 sessions, against about 15 possible at 262k context |
| KV cache used | 4.3% average, 9.9% peak |
| Generation | 2.19M tokens; 134 tok/s average (350 peak), against an estimated 1,000–1,500 tok/s capacity (not benchmarked) |
| **Capacity used** | **about 10%** |
| Bill | about $29 box plus $0.59 Claude |
| Effective cost at full sharing | about $3–5 |

Root cause of the low use: the harness ran on the laptop, and the SSH tunnel collapsed at 5–7 parallel sessions (13 stalls). Most tasks were sequential.

## 2. Cost per task, measured

| Implementer | Basis | Cost per WP1-class task | Time per task |
|---|---|---|---|
| Sonnet 5.5 | F2-6 full build, $25.65 / 32 tasks | **about $0.80** (incl. retries, peer review, Sonnet/Opus reviews) | 1–4 min |
| Haiku 4.5 | F2-7, $40.39 / 32 tasks | **about $1.26**, *more* than Sonnet (retries) | 1–4 min |
| Laguna S 2.1 BF16, self-hosted, at 100% load | estimated 18–27 tasks/hr per box | **about $0.22–0.33** | 35–45 min |
| same, at 30% load | | about $0.75–1.10 | |
| same, at tonight's 10% load | | about $2–3 | |

Break-even against Sonnet is about **30–40% sustained utilisation** of the self-hosted box.

## 3. Why Laguna is slow

On the same WP1 tasks:

| | Laguna BF16 (our box) | Beam FP8 (Nebius) |
|---|---|---|
| Output tokens, WP1-T1 / WP1-T2 attempt 1 | 38,951 / 91,298 | 7,809 / 13,081 |
| Effective tok/s | 19–37 | 69–74 |

- About 5–7× comes from the **model**: Laguna thinks a lot, about 65% of its output.
- About 2–4× comes from **hardware**: PCIe workstation GPUs vs a datacenter with NVLink, FP8 kernels and speculative decoding.

Capping thinking did not reduce Laguna's total thinking.

## 4. Scaling to 100+ developers (projection)

- Load: about 30–60 concurrent sessions at peak, about 500 GB of KV.
- Hardware: one 8×B200 node at about $42–114/hr, depending on provider, covers this with headroom.
- Monthly cost: about $7–18k at office hours.
- Comparison: Sonnet at about 20 tasks per developer per day is about $37k/month.
- Self-hosting wins only with high, steady usage. It needs the agents co-located with the GPUs and a privacy-cleared reviewer.

## 5. Budget experiments (2026-10-19)

| Test | Spend |
|---|---|
| Laguna BF16 box (one night) | about $29.6 |
| Sonnet full build | $25.65 API-equiv (subscription) |
| Haiku full build | $40.39 API-equiv (subscription) |
| Inkling-Small FP8 (OpenRouter) | $4.71 |
| gpt-oss-120b BF16 (OpenRouter) | about $0.2 (stopped) |
| Beam FP8 (OpenRouter) | about $3.96 (stopped at zero balance) |
