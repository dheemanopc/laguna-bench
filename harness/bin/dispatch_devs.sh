#!/usr/bin/env bash
# dispatch_devs.sh <run_id> <dev1_order|-> [<dev2_order|->]
# Tree shape (F1): the Sonnet DA's ONLY way to change code. Runs up to two Laguna XS developer sessions IN PARALLEL
# on the shared run repo, one per GPU replica:  dev1 -> shim :4000 -> GPU0,  dev2 -> shim :4001 -> GPU1.
# Each developer is its own sub-run (runs/<id>.devN: repo symlinked to the shared repo, its OWN test database,
# its own executor session that later orders resume). "-" skips that developer this round.
# Prints one compact JSON object per developer (same summary format as run_executor.sh).
set -uo pipefail
RID="$1"; shift; B=$HOME/laguna-bench; RD=$B/runs/$RID
[ -d $RD/repo ] || { echo '{"status":"error","error":"unknown run_id"}'; exit 1; }
pids=(); outs=()
for n in 1 2; do
  O="${1:--}"; shift || true; [ "$O" = - ] && continue
  O=$(realpath -m "$O"); case "$O" in "$RD"/orders/*) ;; *) echo "{\"dev\":$n,\"status\":\"error\",\"error\":\"order must be in $RD/orders/\"}"; continue;; esac
  [ -f "$O" ] || { echo "{\"dev\":$n,\"status\":\"error\",\"error\":\"order file not found\"}"; continue; }
  SD=$B/runs/$RID.dev$n
  if [ ! -d $SD ]; then
    mkdir -p $SD/orders $SD/exec; ln -s $RD/repo $SD/repo; cp $RD/baseline_sha $SD/
    DB="lb_$(echo $RID.dev$n | tr -c 'a-zA-Z0-9_\n' _)"
    $B/bin/fresh_db_tpl.sh bench_tpl "$DB" > $SD/run.env; echo "export BENCH_DB=$DB" >> $SD/run.env
  fi
  cp $RD/deadline $SD/deadline 2>/dev/null
  k=$(( $(ls $SD/orders | wc -l) + 1 )); cp "$O" $SD/orders/order-$k.md
  URL=http://127.0.0.1:4000; [ $n = 2 ] && URL=$(cat $B/scratch/dev2_url 2>/dev/null || echo http://127.0.0.1:4001)   # dev2_url: re-route dev2 (e.g. GPU1 lent to another model)
  ( LAGUNA_BASE_URL=$URL $B/bin/run_executor.sh X $RID.dev$n $SD/orders/order-$k.md > $SD/last.json 2>&1 ) &
  pids+=($!); outs+=("$n:$SD/last.json")
done
for p in "${pids[@]}"; do wait $p; done
for o in "${outs[@]}"; do n=${o%%:*}; f=${o#*:}; jq -c --argjson n $n '{dev:$n} + .' $f 2>/dev/null || { echo "{\"dev\":$n,\"raw\":$(jq -Rs . $f)}"; }; done
