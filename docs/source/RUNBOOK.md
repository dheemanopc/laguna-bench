# laguna-bench — Runbook (spawning new tests)

Everything runs from the laptop. One entry point: `~/laguna-bench/bin/lb`.

## Lifecycle of the GPU box (g7e.12xlarge, us-east-1, Laguna S 2.1 FP8 on vLLM 0.25.1, TP2)
| Command | What it does |
|---|---|
| `lb status` | instance state, vLLM health, KV size + active serve flags, tunnel/shim, active bench sessions |
| `lb up` | start the stopped box (weights already on disk; ~10 min to healthy), re-arm the 13 h dead-man switch, refresh the SG to your current IP, ssh_config, tunnel (127.0.0.1:18000 → vLLM) and shim (127.0.0.1:4000) |
| `lb down` | STOP the box (no GPU charge; ~$1.30/day for the 500 GB disk). Refuses while bench sessions are active |
| `lb destroy` | terminate + delete SG/key, verify nothing tagged Project=laguna-bench remains in us-east-1/us-east-2/ap-south-1 |
| `lb serve <profile>` | switch vLLM flags and restart: `base`, `1m` (1M context), `offload` (300 GiB CPU KV offload), `dflash` (spec decode). Add profiles in the PROFILES table in bin/lb |
| `lb curve` | re-run the capacity curve on the box |

## Running a test
1. Write a task: `tasks/<ID>/packet.md` (what the agent sees), `tasks/<ID>/meta.json` (`base_commit`, `db_template`, `needs_migration`, …), hidden tests in `hidden/<ID>/` (mirrors repo paths), optional `tasks/<ID>/visible/`.
2. Run it: `lb run <max_parallel> <ID>:<ARM>:<run_id> …`, e.g. `lb run 4 T1:B:T1-B3 T2:B:T2-B3`
   - ARM `B` = Laguna executor via the shim; ARM `A` = Sonnet executor via your Claude login. The master is always Opus 5.5.
   - Each run: history-less snapshot of the base commit, its own Postgres DB, interactive Claude Code sessions with Remote Control (`lb-<run>-master` is visible in claude.ai/code), 120-min cap, then automatic scoring (`runs/<run_id>/score/summary.txt`).
3. Watch: `lb peek <run_id>` (executor thinking/tool calls), `bin/status.sh`, `tmux attach -r -t rc-lb-<run>-exec<N>_`.

## Experiments ready to go
- `bin/exp_longctx.sh` — 1M-context TTFT + RAM KV-offload "parked agent" test (restarts vLLM 3×; ~40 min).
- `bin/curve.sh` / `bin/bench_point.sh` — capacity points (`vllm bench serve`).
- `bin/prefix_test.py` — cold vs warm TTFT on a ~300k shared prefix.

## Building blocks (bin/)
launch.sh · user-data.sh · ip_guard.sh · gssh · tunnel.sh · shim.py · prepare_run.sh · run_master.sh · run_executor.sh · rc_session.sh · prompt_guard.sh · run_queue.sh · score_task.sh · t6_score.sh · run_hidden.sh · run_tests.sh · fresh_db_tpl.sh · peek.sh · status.sh · scrape.sh

## Gotchas learned
- Laptop :8000 belongs to the local memory-man stack → the tunnel uses 18000.
- Claude Code mid-conversation system messages break vLLM prefix caching → always go through shim.py.
- `claude -p --remote-control` does not register RC → rc_session.sh runs sessions interactively in tmux.
- Executors must not get EnterPlanMode/ExitPlanMode/EnterWorktree/ExitWorktree (Laguna uses them; they derail headless runs).
- Per-call executor timeout must not be shorter than the run budget (Laguna at 4-way sharing can take >45 min for one work order).
- DFlash under TP2 needs --disable-custom-all-reduce (illegal memory access otherwise).
