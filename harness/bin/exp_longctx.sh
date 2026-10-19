#!/usr/bin/env bash
# exp_longctx.sh — long-context + RAM KV-offload experiment (run AFTER benchmark runs; restarts vLLM 3×).
#  A) profile 1m      : --max-model-len 1048576 → KV size + cold/warm TTFT on a ~900k-token prompt
#  B) profile base    : control for the parked-agent test (14 × 128k sessions overflow 1.48M GPU KV)
#  C) profile offload : native CPU KV offload 300 GiB → GPU KV size (hybrid-manager check) + parked-agent test
#  then back to base. Results → results/longctx/*.json
set -uo pipefail
B=$HOME/laguna-bench; O=$B/results/longctx; mkdir -p $O
scp -q -F $B/ssh_config $B/bin/exp_evict.py $B/bin/prefix_test.py gpu:/opt/bench/
$B/bin/lb serve 1m --force | tee $O/1m.kv.txt
$B/bin/gssh "sed -e 's/298000/900000/' /opt/bench/prefix_test.py > /opt/bench/prefix_900k.py && /opt/bench/vllm/bin/python /opt/bench/prefix_900k.py" | tee $O/1m.prefix.json
$B/bin/lb serve base --force | tee $O/base.kv.txt
$B/bin/gssh "/opt/bench/vllm/bin/python /opt/bench/exp_evict.py 14 128000" | tee $O/base.evict.json
$B/bin/lb serve offload --force | tee $O/offload.kv.txt
$B/bin/gssh "/opt/bench/vllm/bin/python /opt/bench/exp_evict.py 14 128000" | tee $O/offload.evict.json
$B/bin/lb serve base --force > /dev/null && echo "restored base profile"
