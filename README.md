# laguna-bench: can a self-hosted open model be a team's *faithful* coding implementer?

A private research log (Oct 2026) evaluating open-weight LLMs as the implementer in a "Sonnet plans and reviews, open model implements, tests and commits" setup, for a team of 100+ developers.

**The bar (Anand):** "As long as it can do faithful implementations, we are good there." Concretely:
- no false "tests pass" claims;
- no edits outside the task's files;
- no weakened checks.

## Findings at a glance (2026-10-19)

| Question | Answer |
|---|---|
| Which open model met the faithfulness bar? | **Only Laguna S 2.1 at BF16**: 0 check-weakening, 0 false claims, 4/4 WP1 tasks. |
| What about compressed models? | Every fp4/FP8 run (Laguna fp4, Inkling-Small FP8, Beam FP8) tried to silence type/lint checks. Beam repeated it despite feedback. |
| Planning quality? | No open model is reliable. One-shot drafts scored 5.0–6.5/10 against 8+ for the approved reference (Beam best design at 6.0, Laguna best plan at 6.5). |
| Correctness? | Even faithful Laguna shipped 5 auth/integrity bugs behind green gates. **Sonnet milestone review is mandatory.** |
| Speed? | Laguna: 35–45 min/task on our 4-GPU box (5–7× more tokens than Beam, plus PCIe hardware). Sonnet: 1–4 min. |
| Cost? | Sonnet full feature: $25.65 in 95 min. Self-hosted Laguna is cheaper only above about 30–40% sustained GPU utilisation. |
| Licences | Laguna S 2.1: OpenMDW-1.1 (permissive). Laguna M.1, Beam, gpt-oss, Inkling: Apache-2.0. Devstral 2 / Mistral Medium 3.5: $20M revenue cap (rejected). EXAONE: non-commercial. |

## Repo map

| Path | Contents |
|---|---|
| `docs/01-context.md` | Goal, constraints, chronology, pivots |
| `docs/02-harness.md` | How the bench works (sessions, guards, gates, faithfulness metrics, f2x pipeline) |
| `docs/03-implementation.md` | All implementation runs compared (WP1 head-to-head, full builds, review defects, precision pattern, guards) |
| `docs/04-planning.md` | Planning/design scores per model |
| `docs/05-economics.md` | Utilisation, cost per task, break-even, scaling |
| `docs/06-infra-lessons.md` | Gotchas: SSH tunnel collapse, vLLM settings, shim, context window, spot instances |
| `docs/07-plan-forward.md` | Pilot and rollout plan, model bake-off, licence notes, candidate survey |
| `docs/source/` | Original decision log (D1–D58), journal, runbook, reports |
| `harness/` | Scripts (`bin/`), prompt templates, task specs, hidden tests |
| `runs/<id>/` | Per-run ledgers, gates, reviews, replay logs, and `repo.diff` in place of the code clone |
| `boxlogs/` | vLLM and setup logs from the GPU boxes |
| `config/*.example` | Placeholder configs (no secrets) |

## Key runs

| Run | What |
|---|---|
| F2-5 | Laguna S 2.1 BF16 full build (self-hosted) |
| F2-6 | Sonnet 5.5 full build |
| F2-7 | Haiku 4.5 full build |
| F2-8 | Inkling-Small FP8 |
| F2-9 | gpt-oss-120b BF16 (stopped) |
| F2-10 | Beam FP8 |
| OR-1 | Laguna fp4 (OpenRouter) replay |
| BF-1 | Laguna BF16 replay (BF-2..4 invalid: tunnel) |
| PL-G*, PL-P* | Planning tests (goal / WP1 plan) per model |

All model scores are on one feature (F2) of one open-source repo (mem-mcp). Treat them as strong signals, not benchmarks. Secrets, IPs, emails and account IDs have been scrubbed. The code clones are replaced by diffs.
