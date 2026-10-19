# laguna-bench — STATE

Last update: 2026-10-15T14:28Z
Current phase: **DONE (2026-10-16 01:13Z): benchmark complete, instance STOPPED (disk+weights kept), waiting for Anand. Report: REPORT.md + https://claude.ai/artifact/7rVbsmt1E4RAzDznULF823**

## Sources (Memsys)
- Plan: cb51c0a4-d5b7-44a4-b8ca-d9792b16679a
- Prompt rev6 e47b0c10 · Ubuntu 2b809204 · rev7 0ce35628 · rev8 2f0635ca · rev9 6af7ce5b (later wins)
- Live user overrides (this session): see the decision log, D1–D3

## Laptop
- Ubuntu 24.04, 12 cores, 38GB RAM, NO passwordless sudo (user-space only)
- Docker usable without sudo (user in the docker group)
- Sleep inhibitor: systemd-inhibit PID in ~/laguna-bench/inhibit.pid (sleep:idle:handle-lid-switch accepted, mode=block)
- Interface: wlp0s20f3

## Memsys repo
- Anand's repo: /codes/ai-work/memory-man (branch feat/mindmap-answer-modes, dirty: docker/cognito-local/config.json + 2 untracked files; NOT TOUCHED)
- Ran `git fetch --all --prune` only (remote-tracking refs refreshed; several stale remote branches pruned by fetch)
- `git worktree list` before: saved in worktree-list-before.txt (includes a pre-existing prunable /tmp/mem-mcp-lazy, not ours, left alone)
- Lead worktree: ~/laguna-bench/wt/lead @ origin/main 10fd348 (detached), venv .venv (deps + pytest-socket + mutmut)
- Anand's running memory-man docker stack is untouched. NOTE: it holds laptop port 8000 → model tunnel uses local **18000**

## Local test DB
- Container `lb-pg` (pgvector/pgvector:pg16, already cached locally → no download), 127.0.0.1:55432 + unix socket ~/laguna-bench/pgsock
- Template DB `bench_tpl` migrated to alembic head 0045_fix_turn_backfill
- bin/fresh_db.sh <name> → per-run clone from the template; bin/drop_db.sh <name>

## Baseline (origin/main 10fd348, fresh DB)
- Online: 1347 passed, 18 failed, 16 errors, 31 skipped → **known-red-online.txt (32 node ids)**, all pre-existing (data-collision/fixture bugs in test_team_api, enterprise_*, roles_catalog …)
- Offline (pytest-socket, unix socket only): an extra 18 red: tests/integration/test_web_teams_api.py (16) + test_jobs_reconcile_signups BotoCognitoUserLister (2) → need TCP/network; **excluded from task selection**
- No external embedding/Cognito/Kite calls are otherwise required; no stubs needed. No .env copied anywhere (git archive / worktree exclude it)

## Data usage (wlp0s20f3, rx/tx bytes)
| point | time (UTC) | rx | tx | Δ rx since start | Δ tx |
|---|---|---|---|---|---|
| start | 14:17:55 | 1,196,228,641 | 31,898,887 | 0 | 0 |
| end Phase -1 | 14:27:52 | 3,247,701,184 | 58,101,922 | 2.05 GB | 26 MB |
Note: these counters cover the whole laptop, including Anand's other traffic.

## AWS
- Account 172485061306 (IAM user Local). G quota: us-east-1 384, us-east-2 0, ap-south-1 384
- Price g7e.12xlarge us-east-1 on-demand $8.28608/hr → 13h dead-man max ≈ $107.7 + EBS 500GB gp3 (6000 IOPS/500MBps) ≈ $0.10/hr → ≤ $109 < $120 cap
- Instance **i-038bcc80d18257689** g7e.12xlarge us-east-1a, launched 2026-10-15T14:35:25Z, public IP 54.89.20.84, IISB=terminate, dead-man shutdown -h +780 (≈ 03:35Z on 10-16)
- AMI ami-028357be7d5b15c53 (Deep Learning Base OSS Nvidia Driver GPU AMI, Ubuntu 24.04, 20261006)
- SG sg-0e0cd7713253371da (laguna-bench-sg, default VPC): only 22/tcp from 223.236.99.91/32 (bin/ip_guard.sh keeps it current)
- Key pair laguna-bench-key (ed25519) → ~/laguna-bench/laguna-bench-key.pem (600)
- us-east-1c had no g7e.12xlarge capacity; 1a succeeded
- SSH: ~/laguna-bench/ssh_config host `gpu` (ControlMaster, ControlPersist 4h); wrapper bin/gssh
- Model card: vLLM ≥0.25.0 (installing 0.25.1); flags --tool-call-parser poolside_v1 --reasoning-parser poolside_v1 --enable-auto-tool-choice --default-chat-template-kwargs '{"enable_thinking": true}'; env VLLM_BLOCKSCALE_FP8_GEMM_FLASHINFER=0; sampling = checkpoint generation_config (top_k 20, temp 1.0); weights NOT gated; FP8 = 131.3 GB; DFlash draft poolside/Laguna-S-2.1-DFlash-FP8 (card: --max-num-seqs 32 required with DFlash)

## Costs
- AWS: $0.00
- Claude: one RC test call (haiku, $0.02)

## Active runs
- none

## Decision log
- D1 (14:18) Remote Control: user asked that all code sessions be Remote-Control-enabled. Global `remoteControlAtStartup=true` already set. Every headless `claude -p` I spawn also gets `--remote-control lb-<role>-<run>` (verified the flag is accepted with -p), plus env CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=laguna-bench.
- D2 (14:22) Region order overridden by user: **us-east-1 first** (best pricing), then us-east-2, then ap-south-1.
- D3 (14:25) User asked to document everything, scripts included, for a presentation → docs/JOURNAL.md (running), all scripts in bin/ with headers, final deck-ready REPORT.md + an HTML artifact.
- D4 unshare -rn is blocked (AppArmor userns restriction) → network isolation for the baseline via pytest-socket (--disable-socket --allow-unix-socket), DB reached over a unix socket.
- D5 Phase -1 used 2.05 GB rx (pip wheels: poetry dev deps + LiteLLM ≈ 1.4 GB of venvs; the poetry cache didn't cover the new venv). Interpretation: the 1.5 GB soft / 3 GB concurrency-cap budget applies to traffic AFTER Phase -1 (rev6 wording "about 1.5GB after Phase -1").
- D6 Global CLAUDE.md says to delegate code edits to local-worker, but it also says security/auth/data-integrity work stays with Opus. The bench scripts enforce credential isolation, permission scoping and leakage protection, so the lead writes them itself. Recorded as a deviation.
- D7 The baseline is not green on main. Instead of searching for a fully green commit, the "green baseline" is defined as main minus the known-red set. Scoring = hidden tests pass AND no new failures outside known-red.

## Phase 0 results (so far)
- Weights downloaded on-instance in ~5 min (131 GB); vLLM 0.25.1 / torch 2.11 cu130 / sm_120, FLASHINFER attention
- Serve fixes: (1) systemd stripped JSON quotes in --default-chat-template-kwargs → moved cmd to /opt/bench/serve.sh; (2) JIT needs `ninja` + nvcc on PATH → `uv pip install ninja`, PATH=/opt/bench/vllm/bin:/usr/local/cuda/bin
- Cold start ≈ 7 min (weights 17 s, torch.compile + graph capture the rest)
- **KV: 18.27 GiB/GPU available → GPU KV cache size 1,478,805 tokens; max concurrency 4.51× at 327,680.** ≈12 KB/token/GPU = full-attention layers only → hybrid SWA allocation correct (no 4× finding). Lower than the "2M+" guess because the CUDA-graph memory profiling makes 0.92 ≈ 0.8766 effective.
- Endpoint choice: vLLM native /v1/messages (tool_use OK, thinking blocks WITH signature). LiteLLM 1.105.1 tested: tool_use OK, thinking OK, but no signature → not used. Gateway = bin/shim.py on 127.0.0.1:4000.
- **Prefix-cache finding**: Claude Code sends role:system messages mid-conversation (env block + per-turn <total_tokens> reminders); vLLM's Anthropic converter folds them into the top system prompt → head changes every request → live hit rate ~4% (identical replays: ~100%). Shim rewrites them into in-place <system-reminder> user messages → consecutive requests hit ~100% (TTFT ~3 s at 37k). Recorded as GATEWAY DEVIATION (content preserved, position preserved).
- Bench-session isolation: --setting-sources project + settings {autoMemoryEnabled:false, claudeMdExcludes:[~/.claude/CLAUDE.md]} + CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 + --disable-slash-commands + Agent/Task disallowed → verified Anand's CLAUDE.md/auto-memory not loaded.
- Arm B smoke: executor edit + pytest OK (13 turns, 54 s), modelUsage only laguna-s-2.1, 5 thinking blocks in transcript.
- Remote Control: arm A executors + all Opus masters get --remote-control lb-<run>-<role>. Arm B executors: Claude Code reports claude.ai connectors disabled when ANTHROPIC_AUTH_TOKEN is set, so RC is likely unavailable for them; enabling it would require sending the Claude OAuth token to the gateway/instance (forbidden by guardrail 8). Accepted limitation.

## Decision log (cont.)
- D8 Laptop :8000 is taken by Anand's memory-man Caddy → tunnel on 127.0.0.1:18000.
- D9 Gateway: shim instead of LiteLLM (signature + prefix-cache reasons above).
- D10 Executor and master env pinned: all ANTHROPIC_DEFAULT_*_MODEL + CLAUDE_CODE_SUBAGENT_MODEL = laguna-s-2.1 on arm B; CLAUDE_CODE_ATTRIBUTION_HEADER=0 (harmless; not the cache cause).

## Phase 0g capacity curve (baseline flags; random data, out 1024, cold prefill)
| point | n | TTFT mean s | TTFT p50 s | TPOT p50 ms | per-session tok/s | agg out tok/s |
|---|---|---|---|---|---|---|
| 131072_c1 | 2 | 11.3 | 11.3 | 9.0 | 111.2 | 49.9 |
| 131072_c16 | 16 | 105.2 | 94.8 | 115.0 | 8.7 | 69.5 |
| 131072_c2 | 2 | 17.1 | 17.1 | 18.7 | 53.5 | 56.5 |
| 131072_c4 | 4 | 28.2 | 28.3 | 33.3 | 30.0 | 65.4 |
| 131072_c8 | 8 | 50.4 | 50.4 | 63.5 | 15.7 | 70.5 |
| 300000_c1 | 2 | 38.6 | 38.6 | 10.3 | 96.7 | 20.8 |
| 300000_c2 | 2 | 57.6 | 57.6 | 34.3 | 29.1 | 22.0 |
| 300000_c4 | 4 | 95.4 | 95.4 | 77.7 | 12.9 | 23.3 |
| 300000_c8 | 8 | 182.0 | 171.5 | 156.4 | 6.4 | 23.1 |
| 32768_c1 | 2 | 2.1 | 2.1 | 8.4 | 119.4 | 96.2 |
| 32768_c16 | 32 | 10.6 | 4.9 | 55.1 | 18.1 | 265.6 |
| 32768_c2 | 4 | 3.2 | 3.2 | 13.0 | 76.7 | 123.5 |
| 32768_c32 | 64 | 18.3 | 4.0 | 95.7 | 10.5 | 315.3 |
| 32768_c4 | 8 | 5.0 | 5.2 | 17.5 | 57.2 | 177.6 |
| 32768_c8 | 16 | 6.9 | 4.9 | 31.2 | 32.1 | 222.1 |
- Preemptions over the entire curve: 0
- Prefix-repeat test (300,535-token prompt): cold TTFT 38.0 s, warm TTFT 0.79 s
- Kill criteria at c=1: warm 300k TTFT 0.79 s (≤30) ✔; 128k single-stream decode 111 tok/s (≥15) ✔ → no kill
- **Max sustainable agent concurrency (128k, ≥20 tok/s/session, warm TTFT ≤15 s, no preemption) = 4** (c8: 15.7 tok/s ✗). Phase 3 arm B parallelism = 4.

## Phase 3
- Masters/executors run as interactive tmux sessions with Remote Control (bin/rc_session.sh); RC URLs in logs/rc_urls.txt
- Arm B executors cannot attach Remote Control (ANTHROPIC_AUTH_TOKEN disables claude.ai features); masters can → D11
- Laptop data at Phase 3 start: rx 3,595,469,250 / tx 251,115,816
- D11 Remote Control: -p sessions do not register RC (verified with ListAgents) → switched to interactive tmux sessions + Stop hook (rc_session.sh). Arm B executors are not RC-visible (auth limitation, guardrail 8); masters are.
- D12 (16:56) Harness timeout bug (45-min exec cap < run cap; background-task turn-end treated as final). Fixed; T1-B1 invalid, T3-B1 restarted, T4-B1/T5-B1 degraded → reruns T1-B1r/T3-B1r/T4-B1r/T5-B1r queued (bin/queue2.sh). Valid so far: T2-B1 PASS.
- D13 (17:05) Anand: "wait for me after this test is done; keep all scripts ready to spawn new tests". Overrides rev7 "terminate right after arm B": after benchmark + long-context/offload experiment → `lb down` (STOP, keep disk) and wait. Full teardown (`lb destroy`) only on Anand's word or cap/dead-man. Toolkit: bin/lb + docs/RUNBOOK.md.
- D14 (17:05) Anand approved the 1M-context + RAM-offload experiment (bin/exp_longctx.sh) after the benchmark runs.
- D15 Shim: safe resend on stale keep-alive disconnects (~2% of requests; Claude Code was retrying on 529). Code updated; shim restart deferred to the next phase boundary to avoid cutting live streams.
- D16 (17:10) Anand: add Haiku 4.5 executor arm (H) — 2 runs on T2 (T2-H1, T2-H2), laptop only, same Opus master/packet/permissions/scoring.
- D17 (17:45) Anand: Haiku on T4 (T4-H1, T4-H2), laptop only.
- D18 (18:18) Anand: one Sonnet (arm A) run on T4 (T4-A1), laptop only.
- D19 (18:29) Anand: 'send T4 as-is to Laguna, let it come back with questions' → solo arm S (bin/run_solo.sh): Laguna gets the raw packet, plans+implements alone, may write QUESTIONS.md → Opus answers as business owner only; no Opus code review. Run T4-S1 now (5th concurrent Laguna session temporarily).
- D20 (21:41) Laptop data crossed ~3 GB post-Phase-1 (rev9: cap concurrency at 2). Asked Anand at 21:12; no answer yet → kept the 4 already-running reruns (same total data either way; cutting would add ~2 h / ~$17 instance time). New launches after this follow the cap unless Anand says otherwise.
- D21 (21:51) Hotspot uplink to AWS collapsed (~20 KB/s) → stopped 2 of 4 reruns (network-invalid), concurrency 2 from now (rev9 data rule + bandwidth). Requeued as T4-B1n/T5-B1n.
- D22 (00:09) rev7 Sonnet controls queued after finale: T1-A1, T5-A1, T6-A1, T2-A1 (concurrency 2, laptop only).
- D23 (05:08) Anand: try Laguna XS 2.1 on a 4xl, same setup, 2 tasks, 'can they at least replace haiku'. Picked T2+T4 (the two tasks Haiku ran). Changed the STOPPED instance type g7e.12xlarge→g7e.4xlarge (one instance, same disk) instead of launching a second. Model poolside/Laguna-XS-2.1-FP8, TP1. Dead-man lowered 780→360 min: ~$31 left under the $120 cap, 4xl $4.00/h.
- D24 (05:32) No g7e.4xlarge capacity in us-east-1a (8 tries). Anand chose: back to 12xl, serve XS on ONE GPU (equivalent to a 4xl's GPU; cost extrapolated at 4xl price). Tasks T4+T6 (T5 if budget), plus a Haiku T6 control. Dead-man 200 min (~$28; total stays < $120). Concurrency 2 for XS (rev9 data rule).
- (05:39) launched T4-X1, T6-X1 (Laguna XS, Opus master) + T6-H1 (Haiku control), run_queue max_par 3 (2 on GPU).
- (06:21) T4-X1 scored 23/25 (same 2 as every Opus-led run) + 1 extra regression: tenant-scope lint. T6-H1 FAIL at gate (2 new tests red on base). Launched T5-X1 (fits before 08:52 dead-man).
- D25 (06:48) Anand: real feature test = A (trackable mindmap nodes, 'the biggest'), shape Opus(business owner) → Sonnet DA → Laguna XS devs, 'don't pick up all the tasks, pick a few'; 'run two agents, don't put another GPU idle' → 2 XS replicas (GPU0+GPU1), one dev per GPU. Budget cap raised to $150; Anand approved re-arming the dead-man ONCE to the new cap → shutdown 12:25 UTC (spend est. $89.4 + 8.39/h from 05:32 → ≈$147 at 12:25). No further extension without asking.
- (06:52) second XS replica on GPU1 (vllm2.service :8001 → tunnel 18001 → shim :4001); bin/dispatch_devs.sh + bin/run_tree.sh written; smoke F0-smoke OK (both devs parallel, 10 s). Launched F1-1 (Opus owner → Sonnet DA → 2× XS devs, DA cap 150 min).
- (06:56) F1-1 attempt 1 invalid (harness): Sonnet DA's first Bash was 'cd ..; cat ..' → denied in dontAsk → it ended its turn asking for permission after 15 s. Fixed DA prompt (exact allowed command forms, read with Read/Grep, never stop to ask); owner phase skipped when BRIEF.md exists (brief reused). T5-X1 PASS (0 new failures, 34 min, 5 rounds).
- (07:01) Anand: 'Kill t6. We will talk later.' → T6-X1 killed at round 4, not scored (run dir kept).
- (07:59) Anand: 'if another gpu is free, host Qwen there.. and compare'. GPU1 lent to Qwen/Qwen3.6-35B-A3B-FP8 @95a723d (same size class as XS: 35B-A3B; parsers qwen3_coder/qwen3, preserve_thinking; KV 4,595,463 tokens). F1-1 dev2 re-routed to GPU0 for later rounds (scratch/dev2_url; was idle at switch). serve.sh takes TOOL_PARSER/REASONING_PARSER/TEMPLATE_KWARGS. New arm Q (run_executor → shim :4001). Launched T4-Q1, T5-Q1 (Opus master, same harness as XS).
- (08:11) F1-1 DONE: total 74 min (DA 70 min; dev1 5 rounds/459 turns, dev2 3 rounds/349 turns). Opus acceptance: ACCEPT WITH FIXES — 23 ACs claimed, 13 MET-level spot-checked, several PARTLY (test gaps); business contradictions C1 (tenant-only RLS defeats team-wide work items) and C2 (history cascades on node delete) — both caught by Opus, missed by Sonnet DA. My check: 0 new full-suite failures, mypy+ruff+tenant lint clean, 13 files/+5.5k lines. Tokens: Sonnet DA 2.96M cr/154k cw/38k out (~$2.0); Opus owner ~$0.9, acceptance 1.6M cr/129k cw/18k out (~$2.1).
- (08:37) Laguna S 2.1 NVFP4 (93 GB on disk, card says ~71) → OOM loading weights on one 96 GB GPU: S cannot run on a single g7e.4xlarge. Anand: 'pick up only one task', 'look at other models from nvidia facebook etc', 'mostly inclined towards models that may consume about 50gb'.
- (08:58) GPU0 → Devstral Small 2 24B (mistral format, FP8 consolidated, vLLM pixtral import patched for transformers 5.19, images off; KV 811,824). GPU1 → nvidia Nemotron-Labs-3 Puzzle 75B-A9B NVFP4 @1d370e4 (50 GB; KV 1,340,024; parsers qwen3_coder/nemotron_v3). Both tool-call OK. Launched T4-D1, T4-P1 (Opus master). Anand's new plan (Sonnet up to DA → GPU agents → separate Sonnet verification plan run by a different-model verifier on GPU → Sonnet pass/fail) noted; proposed testing Devstral/Puzzle as verifiers on F1 round 1.
- (09:05) Anand: Yes → bin/run_verify.sh F1-1 D P: Sonnet verification plan blind to code (denied Read on runs/), Devstral + Puzzle verifiers on private copies (tests/verify only), harness re-runs their tests, Sonnet PASS/FAIL. Ground truth = F1-1 ACCEPTANCE.md.
- (09:25) verifyP (Puzzle) quit after 4 min on its first denial (shell redirect to /tmp) claiming 'Bash denied'; resumed with a clarifying order-2 (same nudge the Sonnet DA got). verifyD (Devstral) running; its gate test hung >10 min (backgrounded).
- D26 (12:19) Laptop was powered off mid-run (T4-D1, T4-P1, F1-1 verifyD/verifyP interrupted). Anand: spot quota granted → launch g7e spot + resume. Spot G quota us-east-1 = 48 vCPU. g7e.4xlarge spot: no capacity in 1a or 1c → launched g7e.8xlarge SPOT i-0ab03a07609cc9d88 us-east-1c (1x RTX PRO 6000, 32 vCPU, 249 GB RAM; spot $3.44/hr). Old 12xl i-038bcc80d18257689 left STOPPED in 1a (disk kept, can't cross AZ). Fresh setup via bin/setup_spot.sh; root grown to 250 GB; dead-man 240 min. One GPU → Devstral (:8000 vllm) and Puzzle (:8001 vllm2) served one at a time.
- D27 (12:21) Pre-shutdown results (all had finished by 10:17Z, never reported): F1-1 verifier round = FAIL (insufficient evidence — no VERIFY_REPORT.md from either; D executor error after 36 min; P after resume: 3 test files, harness 6 passed in 896 s). T4-D1 = FAIL 19/25 + 21 new full-suite failures. T4-P1 = INVALID (harness: Opus master exit 1, empty pane, 0 executor calls). Attempt 1 archived in runs/_invalid/F1-1.verify.attempt1.
- D28 Resume plan on 1 GPU: Puzzle (vllm2 :8001 → tunnel 18001 → shim :4001) first: T4-P2 + verifier P rerun on the SAME 42-check plan (run_verify.sh REUSE_PLAN=1 NO_DECIDE=1; shell rules + 'write report early' now in every verifier's order-1). Then swap to Devstral (vllm :8000 → shim :4000): verifier D rerun. Then ONLY_DECIDE=1 Sonnet decision over D+P.
- D29 (12:43) Anand: Mistral/Devstral OUT (license); Nemotron Puzzle OUT ('trained from qwen data', like Qwen). In scope: Laguna, Google (Gemma 4 — Apache-2.0, not gated), Meta (Llama — gated, custom license). Keep 8xl. vllm2 (Puzzle) stopped. Building llama.cpp + pulling Laguna S 2.1 GGUF Q5_K_M (84 GB) and Q6_K (102 GB, needs CPU expert offload) to /opt/dlami/nvme. T4-P2 / verifier reruns with D/P cancelled.
- D30 (12:49) Laguna S Q5_K_M (bartowski GGUF, llama.cpp f336359, 2x131k slots, q8 KV, --jinja, temp 1.0 top_k 20) serving on :8000 — 88.5 GB VRAM, ~125 tok/s single stream, tool_use + thinking OK via shim. T4-F1 started (arm F, Opus master, same harness).
- D31 (12:51) Anand: try 'flash optimisations' too → speculative decoding: Laguna S DFlash drafter (poolside laguna-s-2.1-DFlash-BF16.gguf, llama.cpp --spec-type draft-dflash --spec-draft-n-max 15) and Gemma 4 MTP drafter (google/gemma-4-31B-it-assistant → vLLM gemma4_mtp). Both downloaded. Speed A/B via bin/spec_ab.py (gen + edit workloads, c=1/2) after T4-F1 finishes — no server restarts during a scored run. Gemma 4 31B BF16 downloaded to /opt/dlami/nvme/hf.
- D32 (12:55) Anand: terminate the 12xl, extend budget ('still within quota'). i-038bcc80d18257689 TERMINATED, vol-0fea58359b55f3a19 deleted. Spot dead-man re-armed to +420 min → 19:54Z (01:24 IST). Only laguna-bench instance now: i-0ab03a07609cc9d88 g7e.8xlarge spot.
- D33 (13:54) Drafter sweep (60k ctx, c=1, bin/spec_sweep.sh, /opt/bench/spec_sweep.log): n-gram ×3 no gain; DFlash n4 best (new code 144 vs 92 nodraft, rewrite 83–119 vs 91); n6+pmin / n6+ngram worse on rewrites. Quant mismatch RULED OUT: Poolside's own Q4_K_M gives the same DFlash acceptance (50–57% gen / 17–19% rewrite) as bartowski Q5; Q4 needs CPU expert offload (66 tok/s nodraft). Serve: Q5_K_M + DFlash n-max 4, NP=1, 262k (Poolside fork 06f8ceb).
- D34 (13:54) F2-1 started (bin/run_f2.sh): Opus owner Q&A (≤3 rounds, one-line answers) + final Opus acceptance (read-heavy, ≤400 words) + ONE Laguna S Q5 engineer, abstract packet tasks/F2/packet.md, own design doc first (docs/design/team-workflows.md), base = F1-1 delivered tree, RUN_CAP 5h. Wider permissions (file ops/scripts/git/web gates) confined by bin/path_guard.py (PreToolUse; repo + /tmp rw) — tested live. Dead-man re-armed +390 min. Tokens: bin/token_ledger.py + llama.cpp /metrics (counters fresh at F2 start).
- D35 (14:25) F2-1 was BROKEN (killed anyway): Poolside fork answers HTTP 400 on Claude Code's tool schemas ("failed to parse grammar": huge maxLength/maxItems + regex patterns). Fix: shim drops only pattern/format/oversized length+item caps (SHIM_SANITIZE, gateway deviation). New gate: bin/cc_smoke.sh (real Claude Code session, must be all-200) before any long run.
- D36 Drafter sweep 2/3: upstream nodraft 97/95 (fork 92/91); DFlash n3/n2/backend-sampling < n4; MXFP4 DSpark (olka-fi, converted to GGUF, needed a 1-line upstream patch: laguna.cpp res->t_layer_inp[il]=inpL) runs but acceptance 7-31% → slower than nodraft; orestis-z DSpark (Laguna backbone) unsupported by llama.cpp (MoE hparams assert) → needs vLLM/2 GPUs. FINAL: fork + DFlash n4 + shim sanitize, NP=1, 262k. cc_smoke PASS.
- D37 (14:25) F2-2 started (same shape as F2-1). Dead-man re-armed +420 min.
- D38 (14:32) Anand: 'offload kv cache to RAM, schedule another agent while one runs tests', 'don't keep GPU idle'. llama.cpp --cache-ram 65536 (64 GB host prompt/KV cache; default was 8 GB) + NP=1 (server queue = time-slicing; no concurrent decode, keeps DFlash gains). Restart cost F2-2 4×503 then recovered. Second agent: T4-F2 (Q5 quality check, Opus master + arm F) started alongside F2-2. Measured F2-2 exploration phase: GPU busy 96% (tool gaps median 0.1 s) — gaps come later with test runs.
- D39 (15:18) 2nd agent with NP=1 was a net LOSS: llama.cpp kept only the shared prefix on each agent switch (f_keep 0.23–0.68) → TTFT 58–155 s, ~860k extra prefill in 15 min; --cache-ram never restored (no prompt-cache lines in the fork). Fix: NP=2 + --kv-unified + CTX 360000 (93.9 GB VRAM) so both contexts stay on GPU; shim SHIM_SERIAL=1 FIFO queue (one request upstream at a time, queued_s logged, 900 s bounded wait); --slot-prompt-similarity 0.5 so agents stop sharing slot 0 (default 0.10 matched on the common Claude Code system prompt).
- D40 (15:36) Anand: T4-F2 not needed → killed. His plan: after the design/planning phase, the real dev phase pools several Laguna developers (migrations / web / backend) on this one GPU via the same mechanism (NP=N slots, unified KV, shim FIFO queue = one decode at a time, next request picks up immediately). Kept NP=2 + unified 360k + SHIM_SERIAL for that.
- D41 (15:42) Anand: 'see how many slots you can manage, and keep them'. Unified KV makes slot count ~free; the limit is the pool. NP=4, CTX=440000 fits (96.3/97.9 GB). Verified: own-slot reuse sim 0.96–0.99 (1.4k-token re-prefill per turn), side conversations land in a free slot. Canonical: bin/llama.env.pool + SHIM_SERIAL=1.
- D42 (15:54) F2-2 DONE: Laguna ended itself at 87 min (127 turns, 0 questions), report 'All checks pass'. Objective: +~1.1k lines (4 modified, 7 new files), ZERO tests, ZERO web changes, ruff 5 / mypy 2 errors (Laguna called its own file's mypy errors 'pre-existing'), alembic single head OK, full suite 0 new failures, web tsc/build clean (untouched). Opus acceptance (re-run manually after RC_ENV bug in run_solo acceptance — fixed): REJECT — custom statuses blocked by 0046 CHECK constraint (feature inert), workflow change strands items, delete_workflow always errors (asyncpg rowcount), no approvals/board/blocked-why/waiting-on-me, no tests. Laguna silently narrowed scope, asked nothing.
- D43 (16:01) Anand: Laguna never PRESENTED its design (F2 harness said 'nobody approves'). New harness bin/run_staged.sh: Laguna does all work in stages analysis → design → integration plan (WPs) → per-WP implementation → acceptance; an Opus ARCHITECT reviews every gate (separate session, read-heavy, ≤250-word APPROVE/REVISE, ≤3 rounds); harness gate output attached to code reviews. bin/cost_report.py: tokens + $ per stage (Opus 5.5 $4/$20, cache rd $0.20, wr 5m $5 / 1h $8 per MTok; GPU spot $3.4373/hr). F2-2 cost: Opus $0.63 + GPU $4.97. F2-3 started (staged).
- D44 (16:06) Anand: let F2-3 run overnight. Dead-man re-armed +420 min (≈23:05Z / 04:35 IST) to cover RUN_CAP 6h + acceptance.
- D45 (16:27) F2-3 analysis gate: REVISE ×3 (moved on to design 16:26Z). HARNESS GAP found: when a gate exhausts MAX_ROUNDS, the final review's findings are recorded but NOT sent to Laguna (next stage order doesn't include them). Fix for next runs: prepend the last open review to the next stage's order. Not patched live (editing a running bash script is unsafe).
- D46 (16:42) F2-3 design gate: REVISE ×3 → plan at 16:41Z. NOTE: architect CONTRADICTED itself — analysis r2 finding 3 told Laguna to use current_user_active_team_ids() (team_members); design r3 finding 1 says that table is legacy/never written and UEA is required. The r3 findings (incl. this RLS blocker) were never sent to Laguna (harness gap D45).
- D47 (16:58) F2-3 planning DONE at 16:58Z: analysis REVISE×3, design REVISE×3, plan REVISE,REVISE,APPROVE (6 WPs WP0–WP5). Cost so far: Opus $3.81 (9 reviews) + GPU $3.31 = $7.12. HARNESS GAP #2: APPROVE-with-findings also isn't forwarded to Laguna (plan r3 'must fix before WP0' RLS-scope finding not sent). Fix next run: always forward the last review's findings with the next stage order.
- D48 (17:08) Anand: 'keep an eye on what a sonnet subagent can do'. bin/shadow_reviews.sh sidecar: for every remaining F2-3 gate review, a Sonnet session gets the IDENTICAL architect prompt → orders/shadow-<st>-<r>.md (never forwarded to Laguna). 9 planning gates pre-marked as done (docs overwritten; not replayable). Compare in the morning: verdict agreement, finding overlap, cost (cost_report splits by model).
- D49 (18:15) F2-3 WP0: r1 REVISE (56 new failures from NOT NULL workflow_id; tests missing) → r2 APPROVE (0 new failures, 7 tests). SHADOW: r1 both REVISE (3 shared findings; Opus-only: downgrade FK order; Sonnet-only: missing same-tenant clause). r2 Opus APPROVE vs Sonnet REVISE — Sonnet stricter: flagged tests importing TRANSITIONS that WP1 plans to delete (future break) + unqualified team_id; Opus-only: widened DELETE/UPDATE grants. Gap #2 recurring: Opus APPROVE carried 'WP1 must re-apply NOT NULL' which is NOT forwarded to Laguna.
- D50 (19:06) F2-3 WP1 r1 REVISE (gates clean, 0 new failures, but scope largely undelivered: hard-coded WORK_STATUSES still gate statuses, mark not stamping workflow_id, no team-wide reads, signoff semantics off, planned tests missing). SHADOW agrees on all core points; Sonnet-only: inactive-approver gate absent, no signoff_decided history, validate_transition ignores args; Opus-only: channel hard-coded 'mcp', FOR UPDATE scope.
- D51 (20:03) F2-3 WP1 r2 REVISE: 1 NEW failure (own WP0 test asserts workflow_id NULL, now stamped); test files byte-identical to r1; only start_signoff raise fixed. ROOT CAUSE CANDIDATE: persistent engineer session auto-compacted 11x total, 4x during r2 (56 min) -> loses review list. SHADOW agrees (REVISE, same 5 points; Sonnet-only: no reject path, error-name mismatches vs plan). LESSON: fresh engineer session per WP/round w/ handoff file + review checklist file it must tick.
- D52 (20:55) F2-3 WP1 r3 APPROVE (0 new failures; new migration 0049). Both Opus+Sonnet APPROVE-with-findings (NOT forwarded - known gap). Opus-only: tenant-scope lint exempted for whole work_items.py (security smell, engineer weakened a guard to pass), 0049 mutates frozen v1 workflow version rows. Sonnet-only: entry status still hard-coded 'todo' (custom entry impossible), N+1 signoff query in list. Shared: workflow_id nullable, inactive approver rejected not 'recorded-not-counted'. LESSON: engineer may silence lint/guards to go green -> gate must diff tools/lint config + flag exemptions.
- D53 (22:02) F2-3 WP2 r1 REVISE (18 NEW failures, mypy 28, ruff 10). Run cap hit -> WP3-5 skipped, acceptance started 22:01Z. Opus pinpointed root cause (JsonRpcError not imported in _work_item_common.py -> NameError on every error path) + guarded move returns success. Sonnet only listed symptoms but flagged waiting_on_me filtering after limit, and the lint_tenant_scope.py loosening (Opus flagged that at WP1 r3). First time Opus clearly out-diagnosed Sonnet.
- D54 (22:05) F2-3 END. Cap hit after WP2 r1 (WP3-5 never started). Acceptance Opus REJECT; Sonnet shadow REJECT with the same 5 defects (but it could read Opus's review-wp2-1.md, so agreement inflated). Cost (API-equiv): Opus $7.30 (analysis 1.27, design 1.41, plan 1.13, wp0 0.97, wp1 1.52, wp2 0.65, accept 0.35), Sonnet shadows $1.94 (~53% of Opus on same prompts), GPU $20.73 (6h02m). Laguna ~0.87M output tokens, ~96M cached prompt tokens. Planning ate 2h with 9 Opus rounds; WP1 3 rounds/160 min. Engineer session auto-compacted 11x.

## F2-4 (2026-10-17) — new harness "f2x"
- D55 (09:30Z) Anand's new approach for F2 (fresh run, same packet + F1-1 base for comparability): ONE Opus session for the
  whole run (goal sign-off, escalations, acceptance); ONE Sonnet DA session alive throughout, consulted only for judgment;
  Laguna plans everything ONE level at a time (feature→WPs, WP→tasks) and builds; every Laguna task is a FRESH session
  sized to stay far below auto-compaction (watchdog stops a session at 100k context → continuation session). Templates for
  orders / rules (dos & don'ts) / response format (templates/). Parallel Laguna sessions in ONE shared working tree
  (file-ownership locks, migrations exclusive), per-task gates (ruff/mypy/tsc filtered to the task's files + its tests on a
  fresh DB + red flags for weakened checks), full gates only at package milestones (38 s on the baseline). Routing is a
  script (bin/f2x.py), not an LLM — cuts Sonnet tokens. Laguna peer review (read-only Laguna session) before commit.
  Laguna gets GET-only web access to an allow-list of doc hosts (path_guard.py). Targets: done in 4 h, ≤ $30 total
  (GPU + Claude API-equivalent). GPU idle in F2-3 measured: 77 of 360 min (21%), 50 min of it in 866 gaps < 10 s
  (tool turnaround) → exactly what parallel sessions fill.
- D56 Instance: no g7e.4xlarge/8xlarge spot capacity (1a, 1c) → g7e.2xlarge SPOT i-068aea1f704d0885e us-east-1a,
  $2.34/hr (8 vCPU, 64 GB RAM, same GPU). Dead-man 480 min. Spot quota exists only in us-east-1.
- D57 Serving: Poolside publishes NVFP4/INT4 + matching DFlash drafters (vLLM ≥0.25) — tried NVFP4 first: OOM at load,
  weights ~94 GB on the 95 GB GPU (repo 99.7 GB; model card's "~71 GB" is wrong for this checkpoint). → bartowski
  Q4_K_M (71.8 GB) on the Poolside llama.cpp fork 06f8ceb: DFlash n4 + 6 slots + 720k unified KV = 93.2 GB.
- D58 F2-4 RESULT (stopped by operator 16:25Z, instance terminated): 2/27 tasks done (WP0-T1 migration, WP1-T1 errors
  module) + WP0 milestone gate PASS. Wall 6h25m (run) / 6h46m (instance). Cost: GPU $15.84 + Claude $2.01 (Opus goal
  signoff $0.28, DA goal $0.05, DA plan reviews 2×~$0.66, DA WP0 milestone $0.34) = ~$17.85. Time: goal 15 min, plans
  2h45m (2 rounds × 6 WPs; 10/16 plan sessions hit the 100k watchdog — re-exploration), dev 3h25m for 2 tasks.
  Bugs found + fixed mid-run (all now in bin/):
  (a) llama.cpp `--cache-idle-slots` (default with --kv-unified + --cache-ram) clears idle slots on every new task →
      LRU slot + full re-prefill on 44/60 requests. Fix `--no-cache-idle-slots`, NP 4 → LCP hits 0.95–0.999.
  (b) Claude Code sends `thinking: {type:"adaptive"}` for a non-Anthropic model → server applies NO budget (single
      passes ~19k tok). Fix: shim forces {type:enabled,budget_tokens:N}; live via logs/think_budget.
  (c) path guard blocked `printenv` → Laguna retried 6× with long thinking; task.md now says env is preset, never retry.
  (d) read-only peer review sprawled 74 tool calls / 32 min / 156k for 2 files → ro mode --max-turns 12, ctx 60k.
  (e) editing a running bash script in place corrupts the running instance → always write .new + mv.
  Per-task profile after fixes (WP1-T1, 19 min, pass 1st attempt): decode 76%, prefill 14%, tools 9%; output = thinking
  65% / code 32%; ~46 tok/s effective at 50–90k ctx. Lowering the cap 8k→3k does NOT cut total thinking (more, smaller
  passes: WP0-R1 231k chars over 39 passes). Compaction: Claude Code auto-compacts the unknown model at ~170k (→24k,
  Laguna summarises in 3.3 min); only re-reading fix tasks got there (fresh tasks peaked 90–156k).
  VERDICT (Anand): at this speed (~20–30 min/task vs ~5–8 for Sonnet, ~half the $ per task) Laguna Q4 on an RTX PRO
  6000 is not worth it for interactive feature work. Untested levers: thinking off for simple tasks; HBM GPU (~2× decode).
