#!/usr/bin/env bash
# finale2.sh — long-context/offload experiment (deadline-guarded), then lb down (STOP, keep disk) by 03:15Z.
B=$HOME/laguna-bench; LOG=$B/logs/queue.log; HARD=$(date -u -d '2026-10-16 03:15' +%s)
say() { echo "$(date -u +%T) finale: $*" >> $LOG; }
left=$(( HARD - $(date +%s) ))
if [ $left -gt 3000 ]; then say "long-context + RAM-offload experiment (retry)"; timeout $(( left - 900 )) $B/bin/exp_longctx.sh >> $B/logs/exp_longctx.log 2>&1; say "experiment exit $?"; fi
$B/bin/lb serve base --force >> $LOG 2>&1 || true
say "lb down (stop instance, keep disk)"; $B/bin/lb down --force >> $LOG 2>&1
say "instance state: $(aws --region us-east-1 ec2 describe-instances --instance-ids i-038bcc80d18257689 --query 'Reservations[0].Instances[0].State.Name' --output text)"
