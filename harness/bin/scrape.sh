#!/bin/bash
# scrape vLLM /metrics every 30s into /opt/bench/metrics.csv (runs in tmux "scrape")
F=/opt/bench/metrics.csv
[ -f $F ] || echo "ts,running,waiting,kv_usage,preemptions,prompt_tokens,gen_tokens,prefix_hits,prefix_queries,ttft_sum,ttft_count" > $F
while true; do
  m=$(curl -s -m 5 localhost:8000/metrics)
  g() { echo "$m" | grep -E "^$1(\{| )" | awk '{s+=$NF} END{printf "%.4f", s}'; }
  echo "$(date -u +%FT%TZ),$(g vllm:num_requests_running),$(g vllm:num_requests_waiting),$(g vllm:kv_cache_usage_perc),$(g vllm:num_preemptions_total),$(g vllm:prompt_tokens_total),$(g vllm:generation_tokens_total),$(g vllm:prefix_cache_hits_total),$(g vllm:prefix_cache_queries_total),$(g vllm:time_to_first_token_seconds_sum),$(g vllm:time_to_first_token_seconds_count)" >> $F
  sleep 30
done
