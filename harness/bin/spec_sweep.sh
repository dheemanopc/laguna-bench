#!/bin/bash
# laguna-bench — speculative-decoding sweep on the box (Anand: 'see if we have more drafter options, try them before concluding').
# Each variant: rewrite /opt/bench/llama.env, restart llama-server (tmux 'llama'), run spec_ab.py long-context at CONC=1, record acceptance.
# Usage: spec_sweep.sh <variant>...   variants defined below; results → /opt/bench/spec_ab.jsonl + /opt/bench/spec_sweep.log
G5=/opt/dlami/nvme/gguf/Laguna-S-2.1-Q5_K_M/Laguna-S-2.1-Q5_K_M-00001-of-00003.gguf
G4=/opt/dlami/nvme/gguf/laguna-s-2.1-Q4_K_M.gguf
DF="-md /opt/dlami/nvme/gguf/laguna-s-2.1-DFlash-BF16.gguf -ngld 999 --spec-draft-override-tensor .*=CUDA0"
FK=/opt/dlami/nvme/src/llama.cpp-poolside/build/bin/llama-server   # Poolside fork (DFlash)
UP=/opt/dlami/nvme/src/llama.cpp/build/bin/llama-server            # upstream (DSpark; no tool-schema grammar 400s)
MX="-md /opt/dlami/nvme/gguf/laguna-s-2.1-dspark-mxfp4-bf16.gguf -ngld 999 --spec-type draft-dspark"
OR="-md /opt/dlami/nvme/gguf/laguna-s-2.1-dspark-orestis-bf16.gguf -ngld 999 --spec-type draft-dspark"
declare -A V=(
  [q5-ngram-mod]="$G5|--spec-type ngram-mod"
  [q5-ngram-simple]="$G5|--spec-type ngram-simple"
  [q5-ngram-mapk]="$G5|--spec-type ngram-map-k"
  [q5-dflash4]="$G5|$DF --spec-type draft-dflash --spec-draft-n-max 4"
  [q5-dflash6-pmin]="$G5|$DF --spec-type draft-dflash --spec-draft-n-max 6 --spec-draft-p-min 0.3"
  [q5-dflash6-ngram]="$G5|$DF --spec-type draft-dflash,ngram-mod --spec-draft-n-max 6"
  [pq4-nodraft]="$G4|--n-cpu-moe 6"
  [pq4-dflash6]="$G4|$DF --spec-type draft-dflash --spec-draft-n-max 6 --n-cpu-moe 8"
  [pq4-dflash15]="$G4|$DF --spec-type draft-dflash --spec-draft-n-max 15 --n-cpu-moe 8"
  # sweep 2 (third field = binary; default = fork)
  [up-nodraft]="$G5||$UP"
  [up-dspark-mx8]="$G5|$MX --spec-draft-n-max 8|$UP"
  [up-dspark-mx4]="$G5|$MX --spec-draft-n-max 4|$UP"
  [up-dspark-or8]="$G5|$OR --spec-draft-n-max 8|$UP"
  [up-dspark-or4]="$G5|$OR --spec-draft-n-max 4|$UP"
  [fk-dflash3]="$G5|$DF --spec-type draft-dflash --spec-draft-n-max 3|$FK"
  [fk-dflash2]="$G5|$DF --spec-type draft-dflash --spec-draft-n-max 2|$FK"
  [fk-dflash4-bs]="$G5|$DF --spec-type draft-dflash --spec-draft-n-max 4 --spec-draft-backend-sampling|$FK"
)
for v in "$@"; do
  IFS='|' read -r g x bin <<<"${V[$v]}"; BIN=${bin:-$FK}
  printf '%s\n' "GGUF=$g" "SERVED_NAME=laguna-s-2.1-q5km" "CTX=262144" "NP=1" "EXTRA='$x'" "LLAMA_BIN=$BIN" > /opt/bench/llama.env
  tmux kill-session -t llama 2>/dev/null; sleep 3; mv /opt/bench/llama.log /opt/bench/llama.prev.log 2>/dev/null
  tmux new -d -s llama "/opt/bench/llama_serve.sh > /opt/bench/llama.log 2>&1"
  ok=0; for i in $(seq 90); do curl -s -m 3 127.0.0.1:8000/health | grep -q ok && { ok=1; break; }; tmux has-session -t llama 2>/dev/null || break; sleep 5; done
  if [ $ok = 0 ]; then echo "$v FAILED: $(grep -E ' E ' /opt/bench/llama.log | head -2)" | tee -a /opt/bench/spec_sweep.log; continue; fi
  echo "== $v vram=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader)" | tee -a /opt/bench/spec_sweep.log
  CONC=1 python3 /opt/bench/spec_ab.py "$v" laguna-s-2.1-q5km 1024 long | tee -a /opt/bench/spec_sweep.log
  grep -E "draft acceptance" /opt/bench/llama.log | tail -4 | sed 's/.*draft acceptance/  acceptance/' | tee -a /opt/bench/spec_sweep.log
done
