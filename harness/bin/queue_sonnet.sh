#!/bin/bash
# rev7 Sonnet controls (laptop only, no GPU): every task Laguna failed (T1, T5, T6; T4 already has T4-A1) + one it passed (T2).
# Starts after finale.sh (instance stopped) so it never competes with the isolated latency run; concurrency 2 (rev7 + data cap).
while pgrep -f "bin/finale.sh" >/dev/null; do sleep 30; done
echo "$(date -u +%T) queue_sonnet starting (max 2)" >> $HOME/laguna-bench/logs/queue.log
exec $HOME/laguna-bench/bin/run_queue.sh 2 T1:A:T1-A1 T5:A:T5-A1 T6:A:T6-A1 T2:A:T2-A1
