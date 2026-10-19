#!/bin/bash
# reruns of harness-affected runs (fixed regime), started when the main queue finishes
while kill -0 142883 2>/dev/null || pgrep -f "^bash bin/run_queue.sh 4 T4:B:T4-B1" >/dev/null; do sleep 30; done
echo "$(date -u +%T) queue2 starting reruns" >> ~/laguna-bench/logs/queue.log
exec ~/laguna-bench/bin/run_queue.sh 4 T1:B:T1-B1r T3:B:T3-B1r T4:B:T4-B1r T5:B:T5-B1r
