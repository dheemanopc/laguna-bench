#!/bin/bash
# bench_point.sh <tag> <input_len> <concurrency> <num_prompts>  — one capacity-curve point with vllm bench serve (on instance)
set -u; tag=$1; il=$2; c=$3; n=$4; mkdir -p /opt/bench/curve
/opt/bench/vllm/bin/vllm bench serve --backend openai-chat --base-url http://127.0.0.1:8000 --endpoint /v1/chat/completions \
  --model laguna-s-2.1 --tokenizer /opt/bench/hf/hub/models--poolside--Laguna-S-2.1-FP8/snapshots/06d71e91db70a11b08ee6a09c3c4818c85a61953 \
  --dataset-name random --random-input-len $il --random-output-len 1024 --random-range-ratio 0 --ignore-eos \
  --max-concurrency $c --num-prompts $n --seed $RANDOM --percentile-metrics ttft,tpot,itl,e2el --metric-percentiles 50,90,99 \
  --save-result --result-dir /opt/bench/curve --result-filename ${tag}_in${il}_c${c}.json > /opt/bench/curve/${tag}_in${il}_c${c}.log 2>&1
grep -E "Successful|Benchmark duration|Output token throughput|Total Token|Mean TTFT|Median TTFT|Mean TPOT|Median TPOT" /opt/bench/curve/${tag}_in${il}_c${c}.log
