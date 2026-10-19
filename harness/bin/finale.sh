#!/usr/bin/env bash
# finale.sh — unattended end of the 2026-10-15 benchmark session. Deadline-aware: the dead-man switch
# terminates the box at ~03:35Z, so `lb down` (cancel dead-man + STOP, keeping disk/weights) must run by 03:15Z.
B=$HOME/laguna-bench; LOG=$B/logs/queue.log; HARD=$(date -u -d '2026-10-16 03:15' +%s)
left() { echo $(( HARD - $(date +%s) )); }
say() { echo "$(date -u +%T) finale: $*" >> $LOG; }
while pgrep -f "run_queue.sh 2 T4:B:T4-B1n" >/dev/null || pgrep -f "bin/queue3.sh" >/dev/null; do [ $(left) -lt 600 ] && break; sleep 30; done
say "main runs done; restarting shim (retry fix)"
pkill -f "bin/shim.py"; sleep 2; setsid nohup $B/litellm-venv/bin/python $B/bin/shim.py > $B/logs/shim.out 2>&1 < /dev/null & sleep 5
if [ $(left) -gt 3600 ]; then say "isolated speed run T2-B3 (alone on GPU, cap 45 min)"; RUN_CAP=2700 $B/bin/run_queue.sh 1 T2:B:T2-B3; else say "skip T2-B3 (not enough time)"; fi
if [ $(left) -gt 3000 ]; then say "long-context + RAM-offload experiment"; timeout $(( $(left) - 600 )) $B/bin/exp_longctx.sh >> $B/logs/exp_longctx.log 2>&1; say "experiment exit $?"; else say "skip exp_longctx (not enough time)"; fi
# restore base profile if the experiment was cut short, then stop the box
$B/bin/gssh "grep -q EXTRA_ARGS=\"\" /opt/bench/vllm.env || true" >/dev/null 2>&1
say "lb down (stop instance, keep disk)"; $B/bin/lb down --force >> $LOG 2>&1; say "instance state: $(aws --region us-east-1 ec2 describe-instances --instance-ids i-038bcc80d18257689 --query 'Reservations[0].Instances[0].State.Name' --output text)"
