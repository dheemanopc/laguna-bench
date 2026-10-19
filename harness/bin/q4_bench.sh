#!/bin/bash
# laguna-bench F2-4 — Q4_K_M serving choice on ONE RTX PRO 6000 (NVFP4/INT4 do not fit: weights ~94 GB, OOM in vLLM).
# Variants: DFlash n4 vs no drafter, NP slots in one unified KV pool; spec_ab.py long (~60k-token context, warm rep = rep 1)
# at CONC=1,2,4. Picks the parallel-agent setup (Anand: several sessions in memory, next one picked up when the GPU frees).
# Usage (on the box, tmux 'bench'): q4_bench.sh <ctx> <np> <variant>...   variants: dflash4 | nodraft
G4=/opt/dlami/nvme/gguf/Laguna-S-2.1-Q4_K_M/Laguna-S-2.1-Q4_K_M-00001-of-00002.gguf
DF="-md /opt/dlami/nvme/gguf/laguna-s-2.1-DFlash-BF16.gguf -ngld 999 --spec-draft-override-tensor .*=CUDA0 --spec-type draft-dflash --spec-draft-n-max 4"
POOL="--kv-unified --slot-prompt-similarity 0.85 --cache-ram 16384"
CTX=$1; NP=$2; shift 2
for v in "$@"; do
  X="$POOL"; [ $v = dflash4 ] && X="$DF $POOL"
  cat > /opt/bench/llama.env <<EOF
GGUF=$G4
SERVED_NAME=laguna-s-2.1
CTX=$CTX
NP=$NP
EXTRA='$X'
LLAMA_BIN=/opt/dlami/nvme/src/llama.cpp-poolside/build/bin/llama-server
EOF
  tmux kill-session -t llama 2>/dev/null; sleep 3
  tmux new -d -s llama "bash /opt/bench/llama_serve.sh > /opt/bench/llama-$v.log 2>&1"
  ok=0; for i in $(seq 1 120); do curl -sf -m 3 http://127.0.0.1:8000/health >/dev/null && { ok=1; break; }; sleep 5; done
  echo "$(date -u +%FT%TZ) $v ctx=$CTX np=$NP up=$ok vram=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader)" | tee -a /opt/bench/q4_bench.log
  [ $ok = 1 ] || { tail -5 /opt/bench/llama-$v.log >> /opt/bench/q4_bench.log; continue; }
  CONC=1,2,4 python3 /opt/bench/spec_ab.py "q4-$v-np$NP" laguna-s-2.1 1024 long | tee -a /opt/bench/q4_bench.log
  grep "draft acceptance" /opt/bench/llama-$v.log | tail -3 >> /opt/bench/q4_bench.log
done
echo "$(date -u +%FT%TZ) bench-done" >> /opt/bench/q4_bench.log
