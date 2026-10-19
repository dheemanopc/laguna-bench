#!/usr/bin/env bash
# tunnel.sh — keep laptop 127.0.0.1:18000 -> instance 127.0.0.1:8000 (vLLM) [and 18001 -> 8001, second replica] alive over the shared
# multiplexed SSH master. Liveness = a real /health call THROUGH the tunnel (not just "is the ssh process
# alive"): 5 consecutive 45-s timeouts (~4 min, so a slow-but-alive link is never torn down) → tear down the stale master (kill by its pid) and reconnect.
# Every reconnect is logged (events count toward "tunnel/network errors": affected runs are re-run, not scored).
B=$HOME/laguna-bench; C="-F $B/ssh_config"; LOG=$B/logs/tunnel.log; mkdir -p $B/logs; fails=0
while true; do
  if curl -s -m 45 -o /dev/null http://127.0.0.1:18000/health; then fails=0
  else
    fails=$((fails+1))
    if [ $fails -ge 5 ]; then
      echo "$(date -u +%FT%TZ) health failing ${fails}x -> reconnect (stale master)" >> $LOG
      for p in $(ss -ltnp | grep "127.0.0.1:18000" | grep -o "pid=[0-9]*" | cut -d= -f2) $(timeout 5 ssh $C -O check gpu 2>&1 | grep -o "pid=[0-9]*" | cut -d= -f2); do kill $p 2>/dev/null; done   # kill the LISTENER owner too (a dead old master can hold the port)
      rm -f $B/ssh-ubuntu@*; fails=0
    fi
  fi
  if ! timeout 5 ssh $C -O check gpu >/dev/null 2>&1; then
    echo "$(date -u +%FT%TZ) master down -> reconnect" >> $LOG
    $B/bin/ip_guard.sh >> $LOG 2>&1
    timeout 30 ssh $C -fN gpu >> $LOG 2>&1 || { sleep 10; continue; }
  fi
  if ! ss -ltn | grep -q '127.0.0.1:18000'; then
    timeout 10 ssh $C -O forward -L 127.0.0.1:18000:127.0.0.1:8000 gpu >> $LOG 2>&1 && echo "$(date -u +%FT%TZ) forward 18000 added" >> $LOG
  fi
  # second XS replica (GPU1, vllm2.service on :8001) — forwarded as 18001; harmless if nothing listens there
  if ! ss -ltn | grep -q '127.0.0.1:18001'; then
    timeout 10 ssh $C -O forward -L 127.0.0.1:18001:127.0.0.1:8001 gpu >> $LOG 2>&1 && echo "$(date -u +%FT%TZ) forward 18001 added" >> $LOG
  fi
  sleep 10
done
