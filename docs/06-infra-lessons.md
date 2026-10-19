# 06 · Infrastructure lessons

Practical gotchas from the Laguna S 2.1 runs, each as symptom, cause, fix. Decision IDs (D25, D58, ...) refer to the decision log in `STATE.md`; run IDs refer to `runs/`.

## 1. Serving configuration that worked

| Item | Value |
|---|---|
| Hardware | g7e.24xlarge spot, 4x RTX PRO 6000 (96 GB each), about $5.92/h |
| Server | vLLM 0.25.1, BF16 weights (about 235 GB), tensor parallel 4 |
| Flags | `--tool-call-parser poolside_v1 --reasoning-parser poolside_v1 --enable-auto-tool-choice --default-chat-template-kwargs '{"enable_thinking": true}'`, sampling from the checkpoint (temperature 1.0, top_k 20) |
| Context | `max-model-len 262144`; 4,117,023 KV tokens, 15.7 concurrent requests at the full length |
| Start-up | about 9 minutes (weights load in 13 s; compile, profiling and graph capture are the rest: "init engine took 500 s") |
| Prefix cache | hit rate 97.7% in the F2-5 logs, only because of the shim (section 3); zero preemptions |
| Throughput seen | about 115 tok/s single stream, 134 tok/s average and 350 peak over the F2-5 run, at ~10% estimated capacity |
| Endpoint | vLLM's native `/v1/messages` (returns thinking blocks **with signatures**). LiteLLM 1.105.1 worked for tools but dropped signatures, so it was not used (D9). |

The earlier FP8 TP2 box (g7e.12xlarge) gave 1,478,805 KV tokens and a capacity curve of 119 tok/s per agent at 1 agent falling to 10.5 at 32 (aggregate 96 to 315 tok/s at 32k prompts). Sustainable concurrency at 128k with at least 20 tok/s per agent was 4.

## 2. SSH tunnel collapses with 5-7 parallel sessions

- **Symptom:** parallel BF16 replays (BF-2..BF-4) hung; 13 stalls after 23:00 IST; each stalled request waited until the 1-hour task timeout. Never happened with a single session.
- **Cause:** harness on the laptop, vLLM on the box, all traffic through one multiplexed SSH connection. The box was healthy throughout (98% GPU, 115 tok/s).
- **Fix:** co-locate agents with the GPUs (same VPC or host). Every parallel attempt after BF-1 WP1-T1 was marked invalid, not scored against the model. `tunnel.sh` tests liveness with a real `/health` call through the tunnel and reconnects only after 5 consecutive 45 s failures, so slow links are not torn down; it cannot fix a saturated one. Earlier, a mobile hotspot uplink dropped to ~20 KB/s (D21) and SSH compression helped.

## 3. The system-message shim (prefix caching)

- **Symptom:** live Claude Code sessions had a ~4% prefix-cache hit rate and TTFT of tens of seconds, although replaying identical requests hit ~100%.
- **Cause:** Claude Code inserts `role: system` messages *inside* the conversation (environment block, per-turn token reminders). vLLM's Anthropic conversion folds them into the top system prompt, so the head of the prompt changes on every request.
- **Fix:** `harness/bin/shim.py` rewrites each in-conversation system message into an in-place `<system-reminder>` user message (content and position preserved). Hit rate rose to ~98%; TTFT at 37k context about 3 s. It is a recorded gateway deviation; a team gateway needs the same logic. The shim also carries three later fixes: safe resend on stale keep-alive disconnects (~2% of requests, D15), tool-schema sanitising (item 9), and a forced thinking budget (item 4).

## 4. Forced thinking budget did not reduce total thinking

- **Symptom:** single reasoning passes of ~19k tokens on the llama.cpp server.
- **Cause:** Claude Code sends `thinking: {type: "adaptive"}` for a model it does not recognise, so the server applies no budget.
- **Fix attempted (D58b):** the shim rewrites it to `{type: enabled, budget_tokens: N}`. This caps each pass but **does not cut the total**: lowering the cap from 8k to 3k produced more, smaller passes (WP0-R1: 231k characters of thinking over 39 passes). Per-task profile on Q4: decode 76%, prefill 14%, tools 9%; output was 65% thinking and 32% code. Untested: disabling thinking for simple tasks.

## 5. Claude Code auto-compacts unknown models at about 170k

- **Symptom:** sessions on long tasks compacted repeatedly (F2-3: 11 times in one engineer session, 4 times during one 56-minute round, fixing 1 of 5 review findings). Compaction of a ~170k context to 24k took Laguna 3.3 minutes.
- **Cause:** the model name is unknown to Claude Code, so it assumes a small window.
- **Fix:** run fresh, short sessions (100k watchdog), and for long builds pass the model as `laguna-s-2.1[1m]` with `CLAUDE_CODE_AUTO_COMPACT_WINDOW=245000` (below the 262144 server limit). F2-5 and the one-shot planning runs (PL-G, PL-P, peak 138-140k) stayed under the limit; the Q4 runs hit it on both.

## 6. Spot instance gotchas

| Symptom | Cause | Fix |
|---|---|---|
| Cannot stop a spot instance | one-time spot requests only support terminate | Treat every stop as a terminate; keep state outside the instance. |
| Weights and local NVMe gone after termination | instance store is lost | Keep anything important under the root volume or copy back to the laptop. Anand's rule: box-side files are always copied back. |
| Root volume survives (or not) unexpectedly | `DeleteOnTermination` differs per launch script | Set it deliberately. BF attempt 1 kept a 250 GB volume that later had to be deleted by hand; check for orphan volumes after teardown. |
| `InsufficientInstanceCapacity` | capacity is per availability zone | us-east-1a had no capacity for the 24xlarge spot while 1c worked; for the first on-demand 12xlarge it was the other way round (1c none, 1a worked), and 4xlarge/8xlarge spot had none in either. Script a loop over AZs and sizes. |
| Instance forgotten while idle | idle GPU boxes cost $3-6/h | Dead-man shutdown in user data (`shutdown -h +N`, 240-780 min), with `instance-initiated-shutdown-behavior=terminate`. Re-arm deliberately, with the owner's approval, when a run needs longer. The box had no AWS credentials, so `sudo shutdown -h +2` was also the way to stop early. |
| Launch denied | G and VT spot vCPU quota was 0 | Request a quota increase first: 48 vCPU approved (D26), then 192 for the 24xlarge. Plan for the approval delay before a run. Quotas are per region. |
| Laptop offline mid-run | harness ran on the laptop | A powered-off laptop killed four runs at once (D26). Another reason to co-locate. |

Spot prices seen: g7e.8xlarge $3.44/h, g7e.2xlarge $2.34/h, g7e.24xlarge about $5.92/h. Before the quota, on-demand g7e.12xlarge was $8.29/h.

## 7. Editing a running bash script in place corrupts it

- **Symptom:** a running orchestration script (F2-3 at D45, F2-4 at D58e) misbehaved or died after the file was patched.
- **Cause:** bash reads scripts incrementally by byte offset, so changing the file under a live process shifts what it reads next.
- **Fix:** write `<script>.new` and `mv` it into place; for a running instance, patch only at a phase boundary. The same applies to shims: D15's shim fix was deferred to a phase boundary to avoid cutting live streams.

## 8. `pkill -f` matches your own shell

- **Symptom:** a cleanup command killed the shell that issued it.
- **Cause:** `pkill -f <pattern>` matches the full command line, and the line that contains the pattern is itself a command line.
- **Fix:** kill by PID, or anchor the pattern (for example `^bash`). Also kill the owner of a stale tunnel listener explicitly, since a dead old SSH master can hold the port (`tunnel.sh` does this by PID).

## 9. Other gotchas worth keeping

- **`unrecognized_model` warning on stderr.** Every Laguna session prints `[claude-code:unrecognized_model] {"model":"laguna-s-2.1[1m]"...}`. It is harmless; it only explains the 170k compaction default (item 5). Do not treat it as a failure when scanning `.stderr` files.
- **Grammar errors from tool schemas (llama.cpp fork).** Symptom: HTTP 400 "failed to parse grammar" on every turn of F2-1, although a trivial one-tool curl test passed. Cause: Claude Code's schemas carry huge `maxLength`/`maxItems` and regex `pattern`s. Fix: the shim drops only pattern, format and oversized caps (`SHIM_SANITIZE`), and `harness/bin/cc_smoke.sh` runs a real session that must return all 200s before any long run (D35). This does not apply to vLLM.
- **llama.cpp `--cache-idle-slots`.** Default with `--kv-unified --cache-ram`; it clears idle slots when a new task starts, so 44 of 60 requests re-prefilled 20-78k tokens (a plan revision took 30 minutes). Fix: `--no-cache-idle-slots`, 4 slots (prompt-similarity hits 0.95-0.999). Check `/slots` for idle-slot token counts after any multi-session change.
- **Two agents on one slot lost.** With a single slot, switching agents re-prefilled about 860k tokens in 15 minutes and `--cache-ram` never restored them (D39). Use several slots with a unified KV pool, `--slot-prompt-similarity` high enough that agents sharing Claude Code's system prompt do not steal each other's slot, and serialise decode in the shim (D41).
- **Speculative decoding.** DFlash (Poolside's drafter) with n-max 4 gave 144 vs 92 tok/s on new code under llama.cpp, but at two concurrent streams rewrites lost about 40%; n-max 15 was net negative; MXFP4 drafters and n-gram modes gave nothing (D33, D36). Under vLLM TP2 DFlash needed `--disable-custom-all-reduce` or crashed with an illegal memory access.
- **NVFP4 does not fit one 96 GB GPU.** The checkpoint is about 94 GB on disk (the model card says ~71 GB) and OOMs at load (D33, D57). Use Q4_K_M (71.8 GB) there.
- **vLLM startup under systemd.** JSON quotes in `--default-chat-template-kwargs` were stripped (move the command into a script), and JIT kernels need `ninja` and `nvcc` on PATH.
- **Port clashes and `claude -p`.** The laptop's port 8000 belonged to another local stack, so the tunnel uses 18000. `claude -p --remote-control` does not register a Remote Control session; interactive tmux sessions do.
- **Per-call timeouts.** A per-executor timeout shorter than the run budget produced false failures (D12). Under 4-way sharing a single work order can take over 45 minutes.
- **Test DB hygiene.** Unprivileged network namespaces are blocked on Ubuntu 24.04 (D4), so offline tests use pytest-socket and a Unix-socket database; keep a known-red list because `main` has 32 failing tests.
- **Cost of a cold Claude session.** A cold Claude Code call carries about 22k tokens of system prompt (about $0.09 on Sonnet); cold review sessions spent ~65% of their cost on cache writes. Keep one persistent reviewer session per run.
