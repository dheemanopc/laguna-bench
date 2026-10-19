#!/bin/bash
# reruns of network-invalidated T4-B1r/T5-B1r (hotspot uplink collapsed 21:20–21:50Z), concurrency 2 (rev9 data cap)
while pgrep -f "run_queue.sh 4 T1:B:T1-B1r" >/dev/null; do sleep 30; done
echo "$(date -u +%T) queue3 starting network reruns (max 2)" >> $HOME/laguna-bench/logs/queue.log
exec $HOME/laguna-bench/bin/run_queue.sh 2 T4:B:T4-B1n T5:B:T5-B1n
