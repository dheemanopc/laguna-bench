#!/usr/bin/env bash
# total API-equivalent cost of run $1 (default F2-6): engineer sessions (t/*.json total_cost_usd) + DA/Opus (calls.jsonl)
R=$HOME/laguna-bench/runs/${1:-F2-6}
e=$(cat $R/t/*.json 2>/dev/null | jq -s '[.[]|select(.total_cost_usd!=null)|.total_cost_usd]|add // 0' 2>/dev/null)
c=$(jq -s '[.[].cost_usd // 0]|add // 0' $R/calls.jsonl 2>/dev/null); echo "${e:-0} ${c:-0}"
