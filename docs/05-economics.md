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
| Beam on Reflection API + guards, full feature (F2-11) | $1.66 Claude reviews; Beam free tier |

## 6. Token usage per full feature build

The figures are as Claude Code recorded them, summed over all implementer sessions. For Beam they came through the LiteLLM translation; reasoning tokens are counted inside output (OpenAI convention).

| | Beam on Reflection (F2-11) | Sonnet 5.5 (F2-6) | Haiku 4.5 (F2-7) |
|---|---|---|---|
| Sessions | 73 | 101 | 98 |
| Uncached input / cache writes | 4.15M | 2.44M | 4.6M |
| Cached input (reads) | 94.3M | 37.1M | 216M |
| Output | **0.49M** | 0.63M | 1.55M |
| Wall time | 79 min | 95 min | 238 min |
| Cost | $1.66 (Claude reviews only) | $25.65 | $40.39 |

**What F2-11's Beam tokens would cost on OpenRouter** (prices on 2026-10-19; add $1.66 for the Claude reviews):

| Provider (precision) | $/M input · cached · output | Beam tokens | Build total |
|---|---|---|---|
| Together (not stated) | 0.40 · 0.04 · 1.20 | ≈ $6.0 | **≈ $7.7** |
| CoreWeave (fp4) | 1.00 · 0.10 · 3.00 | ≈ $15.0 | ≈ $16.7 |
| Nebius (FP8, no cache price listed) | 0.25 · n/a · 1.00 | ≈ $25.1 | ≈ $26.8 |
| *Sonnet build, for comparison* | | | *$25.65* |

- Agent sessions resend the whole conversation every turn, so **cached-input price decides the bill**: 94M cached tokens against 0.5M output.
- With a ~90% cache discount, Beam costs about ¼ of Sonnet. Without one, it costs about the same.
- Laguna S 2.1 is about 10× cheaper per token on OpenRouter ($0.09 / $0.009 / $0.18) but emits 5–7× more output and runs longer sessions. F2-5 stopped after WP1, so no full-build token comparison is available.
- Reflection publishes no price list; its post-free-tier cost is unknown.

## 7. AWS managed options (checked 2026-10-19)

Neither Beam nor Laguna is on **Amazon Bedrock** as a pay-per-token API. Both are in **SageMaker JumpStart**:
- Laguna S 2.1 (BF16): `ml.g7e.48xlarge`, `ml.p5.48xlarge`, `ml.p5en.48xlarge`.
- Beam BF16 and NVFP4: B200/B300 only. Beam FP8: also `ml.g7e.48xlarge` and `ml.p5en.48xlarge`.

These are on-demand endpoints only, with no spot. us-east-1 hosting prices:

| Instance | $/hr |
|---|---|
| g7e.48xl | $41.43 |
| p5.48xl | $63.30 |
| p5en.48xl | $72.80 |
| p6-b200.48xl | $131.02 |

Default endpoint quotas are 0. JumpStart keeps data inside your own AWS account, which suits the privacy requirement, but it costs 7–20× the EC2 spot price. Use its serving configs as reference and run on EC2 spot.
