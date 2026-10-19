# laguna-bench — Run Journal

Running, append-only log of what was done, the commands, and why. Feeds the final presentation.

## Phase -1 — Front-loaded local setup (14:17–14:28 UTC)

| Step | What | Command / script |
|---|---|---|
| 1 | Keep laptop awake | `systemd-inhibit --what=sleep:idle:handle-lid-switch --who=laguna-bench ... sleep infinity &` |
| 2 | Data baseline | `/proc/net/dev` wlp0s20f3 rx/tx |
| 3 | Locate Memsys repo | find .git dirs under /codes, ~ → `/codes/ai-work/memory-man` (origin github dheemanopc/mem-mcp) |
| 4 | Refresh refs only | `git fetch --all --prune` (never pull/checkout in Anand's tree) |
| 5 | Lead worktree | `git worktree add --detach ~/laguna-bench/wt/lead origin/main` |
| 6 | Deps | venv + `poetry install --no-root` (POETRY_VIRTUALENVS_CREATE=false), `pip install -e . pytest-socket mutmut`; LiteLLM in `~/laguna-bench/litellm-venv` |
| 7 | Test DB | `docker run lb-pg pgvector/pgvector:pg16` on 127.0.0.1:55432 + unix socket; template `bench_tpl` via `alembic upgrade head`; `bin/fresh_db.sh` per run |
| 8 | Baseline | `pytest --disable-socket --allow-unix-socket` (offline) vs online, on a fresh DB each |

Findings
- main is not green: 34 pre-existing red tests → `known-red-online.txt`. A further 18 need the network → excluded.
- Unprivileged netns (`unshare -rn`) is blocked on Ubuntu 24.04, so pytest-socket is used instead.
- Phase -1 data: 2.05 GB rx (pip wheels), 26 MB tx.

## Scripts (bin/)
- `fresh_db.sh <db>`: drop and recreate a DB from template bench_tpl; prints the MEM_MCP_TEST_DSN / MEM_MCP_DB_MAINT_DSN exports.
- `drop_db.sh <db>`: drop a per-run DB.

## Phase 0 — Provision & serve (14:33–15:30 UTC)
- Preflight: STS OK; G-instance vCPU quota us-east-1 384 / us-east-2 0 / ap-south-1 384. Region us-east-1 (Anand's override).
- Price check via the Pricing API: g7e.12xlarge $8.28608/hr, g7e.4xlarge $3.99816/hr (on-demand, us-east-1).
- `bin/launch.sh us-east-1 g7e.12xlarge`: refuses if any laguna-bench instance exists; dedicated ed25519 key; SG laguna-bench-sg with only 22/tcp from the laptop /32; latest DLAMI Base OSS Nvidia (Ubuntu 24.04); 500 GB gp3 (6000 IOPS / 500 MB/s); IISB=terminate; IMDSv2; tags Project/Owner/AutoDelete; tries every AZ (1c had no capacity → 1a).
- `bin/user-data.sh`: `shutdown -h +780` dead-man; uv + vLLM 0.25.1; `hf download poolside/Laguna-S-2.1-FP8` (131 GB in ~5 min) + DFlash-FP8 draft; systemd vllm.service.
- Fixes: JSON quoting under systemd → `/opt/bench/serve.sh`; JIT needs ninja + nvcc → PATH.
- KV: 1,478,805 tokens (18.27 GiB/GPU), so the hybrid SWA allocation is correct.
- Tuning (≤45 min): DFlash (needs --disable-custom-all-reduce under TP2; else illegal memory access) and --max-num-batched-tokens 32768. Both rejected: no aggregate gain at c8×128k, and they cost KV.
- Capacity curve: `bin/curve.sh` + `bin/bench_point.sh` (vllm bench serve, random 32k/128k/300k, out 1k, c=1..32) + `bin/prefix_test.py`, in tmux on the instance. Metrics: `bin/scrape.sh` → /opt/bench/metrics.csv every 30 s.

## Phase 0.5 — Wiring
- SSH: `ssh_config` (ControlMaster/ControlPersist 4h, keepalives, accept-new), `bin/gssh` (retry with backoff + IP guard), `bin/ip_guard.sh` (SG ingress = current hotspot IP /32), `bin/tunnel.sh` (127.0.0.1:18000 → instance :8000, auto-reconnect).
- Gateway: `bin/shim.py` on 127.0.0.1:4000 → vLLM native /v1/messages. Rewrites Claude Code's mid-conversation system messages into in-place <system-reminder> user messages (prefix cache 4% → ~100%). Logs client TTFT to logs/shim.jsonl.
- `bin/prepare_run.sh <Tn> <run_id>`: history-less snapshot (`git archive base | tar -x`, `git init`, one baseline commit), bench CLAUDE.md + CONVENTIONS.md, per-run DB from the task template.
- `bin/run_master.sh <Tn> <run_id> <A|B>`: Opus 5.5 master. Tools: Read/Grep/Glob, Edit only under runs/<id>/orders/, run_executor.sh, git diff/status. No web, no MCP, no AWS. 120-min cap.
- `bin/run_executor.sh <A|B> <run_id> <order_file>`: executor (A = Sonnet via the Claude login; B = Laguna via the shim with all model aliases pinned). Scoped tools: Read/Grep/Glob/Edit/Write + pytest/ruff/mypy/alembic/git status/diff/ls. No web/MCP/Agent. Follow-ups resume the same session. Returns compact JSON.
- Isolation of bench sessions from Anand's global CLAUDE.md, auto-memory and skills: `--setting-sources project`, settings `{autoMemoryEnabled:false, claudeMdExcludes:[~/.claude/CLAUDE.md]}`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, `--disable-slash-commands`. Verified with a probe prompt.
- **Remote Control** (Anand: "make all code sessions remote-control enabled so I can track"): `claude -p --remote-control` is accepted but does NOT register a Remote Control session (verified with ListAgents). So every master and executor now runs as an INTERACTIVE session in tmux with `--remote-control lb-<run>-<role>` and `--permission-mode dontAsk` → `bin/rc_session.sh`. A Stop hook writes the payload; the wrapper rebuilds -p-style JSON from the transcript (usage de-duplicated by message id), records the claude.ai/code session URL, and kills the tmux session. `BENCH_HEADLESS=1` falls back to -p.
- Task scorers (from the task-mining subagent): `bin/score_task.sh` (T1–T5: hidden + visible tests, full suite vs known_red_base, T2 tests-only = fail), `bin/t6_score.sh` (T6: no source changes, new tests green, mutmut kill rate), with helpers run_hidden.sh, run_tests.sh, t6_mutmut.sh, fresh_db_tpl.sh.
- Phase 3 driver: `bin/run_queue.sh <max_parallel> Tn:ARM:run_id ...` (prepare → master → score; idempotent).

## Phase 3–4 — Runs, scoring, controls, experiments (16:07Z → 01:13Z)
- Laguna runs (Opus master): 13 valid + degraded/invalid kept in runs/_invalid. Haiku (4), Sonnet (5), Laguna solo (1). Per-run table: results/runs.md.
- Harness bugs found live and fixed: plan/worktree dialogs (prompt_guard + denied tools), 45-min exec cap, background-task turn-end, relative-path scoring, orphan executors after cap (run_master now reaps), stale SSH listener, hotspot congestion (SSH compression).
- Blind review: results/review/ (scores.json, REVIEW.md; key in results/review_key.tsv).
- Long-context/offload: results/longctx/ (1M fits; 892k cold 245 s / warm 2.1 s; offload resume 1.45 s vs 10.6 s).
- Finale: bin/finale.sh / finale2.sh → lb down (instance stopped, weights kept).
- Report: REPORT.md and docs/report.html (published artifact).
