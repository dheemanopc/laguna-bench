#!/bin/bash
# tp_bench.sh — on the box after setup: start vLLM (BF16, TP4) and measure aggregate decode throughput at ~60k-token contexts
# for CONC=1,8,16,32 (spec_ab.py long). Output: /opt/bench/tp_bench.log + spec_ab.jsonl
cat > /opt/bench/vllm.env <<'X'
MODEL=poolside/Laguna-S-2.1
TP=4
MAXLEN=262144
X
tmux kill-session -t vllm 2>/dev/null; tmux new -d -s vllm "bash /opt/bench/serve.sh > /opt/bench/vllm-bf16.log 2>&1"
ok=0; for i in $(seq 1 180); do curl -sf -m 3 http://127.0.0.1:8000/health >/dev/null && { ok=1; break; }; sleep 10; done
echo "$(date -u +%FT%TZ) bf16 tp4 up=$ok $(nvidia-smi --query-gpu=memory.used --format=csv,noheader | tr '\n' ' ')" | tee -a /opt/bench/tp_bench.log
[ $ok = 1 ] || { tail -30 /opt/bench/vllm-bf16.log >> /opt/bench/tp_bench.log; exit 1; }
( while sleep 15; do echo "$(date -u +%T) util $(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader | tr '\n' ' ')"; done >> /opt/bench/gpu_util.log ) &
CONC=1,8,16,32 /opt/bench/vllm/bin/python /opt/bench/spec_ab.py bf16-tp4 laguna-s-2.1 1024 long | tee -a /opt/bench/tp_bench.log
grep -E "Avg prompt throughput|Avg generation" /opt/bench/vllm-bf16.log | tail -5 >> /opt/bench/tp_bench.log
echo "$(date -u +%FT%TZ) bench-done" >> /opt/bench/tp_bench.log
