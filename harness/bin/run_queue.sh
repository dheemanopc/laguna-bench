#!/usr/bin/env bash
# run_queue.sh <max_parallel> <run_spec>...      run_spec = <Tn>:<arm>:<run_id>   e.g. T1:B:T1-B1
# Phase 3 driver: runs each spec as prepare_run -> run_master (Opus master + executor) -> score,
# at most <max_parallel> at a time. Idempotent: skips runs that already have a score; a run whose
# master.summary.json exists is not re-launched (re-runs after tunnel/rate-limit failures are explicit:
# move the run dir to runs/_invalid/ and requeue). Logs to logs/queue.log.
set -uo pipefail
B=$HOME/laguna-bench; MAXP="$1"; shift; LOG=$B/logs/queue.log
one() {
  IFS=: read -r T ARM RID <<<"$1"; RD=$B/runs/$RID
  [ -f $RD/score/summary.txt ] && { echo "$(date -u +%T) skip $RID (scored)" >> $LOG; return; }
  [ -d $RD ] || $B/bin/prepare_run.sh $T $RID >> $LOG 2>&1 || { echo "$(date -u +%T) PREPARE FAILED $RID" >> $LOG; return; }
  if [ ! -f $RD/master.summary.json ]; then
    echo "$(date -u +%T) start $RID ($T arm $ARM)" >> $LOG
    $B/bin/run_master.sh $T $RID $ARM > $RD/driver.out 2>&1
    echo "$(date -u +%T) master done $RID $(jq -c . $RD/master.summary.json 2>/dev/null)" >> $LOG
  fi
  mkdir -p $RD/score
  if [ "$T" = T6 ]; then $B/bin/t6_score.sh $RD/repo $RD/score > $RD/score/summary.txt 2>&1
  else $B/bin/score_task.sh $T $RD/repo $RD/score/out > $RD/score/summary.txt 2>&1; fi
  echo "$(date -u +%T) scored $RID: $(tail -3 $RD/score/summary.txt | tr '\n' ' ')" >> $LOG
}
for spec in "$@"; do
  while [ $(jobs -rp | wc -l) -ge $MAXP ]; do sleep 5; done
  one "$spec" &
  sleep 20   # stagger master starts (Claude-side rate limits, gateway burst)
done
wait
echo "$(date -u +%T) QUEUE DONE" >> $LOG
