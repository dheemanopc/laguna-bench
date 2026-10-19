#!/usr/bin/env bash
# status.sh — one-screen Phase 3 status: runs, executor calls, scores, RC URLs, GPU load, tunnel events, laptop data
B=$HOME/laguna-bench
for s in $(tmux ls -F '#S' 2>/dev/null | grep -E 'master|exec'); do u=$(tmux capture-pane -p -S -300 -t $s | grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' | head -1); [ -n "$u" ] && grep -q "$u" $B/logs/rc_urls.txt 2>/dev/null || { [ -n "$u" ] && echo "$(date -u +%T) $s $u" >> $B/logs/rc_urls.txt; }; done
printf "%-7s %-8s %-6s %-6s %s\n" run state calls wall score
for d in $B/runs/T*-*; do r=$(basename $d); st=running; [ -f $d/master.summary.json ] && st=done; [ -d $d ] || continue
  c=$(ls $d/exec/*.json 2>/dev/null | wc -l); w=$(jq -r .wall_s $d/master.summary.json 2>/dev/null)
  sc=$(grep -E -o "^(VERDICT|verdict|RESULT|result)[^$]*|PASS|FAIL|DISQUALIFIED|kill rate[^,]*" $d/score/summary.txt 2>/dev/null | tail -1)
  printf "%-7s %-8s %-6s %-6s %s\n" $r $st $c "${w:--}" "${sc:--}"; done
$B/bin/gssh 'tail -1 /opt/bench/metrics.csv' 2>/dev/null | awk -F, '{printf "gpu: running=%s waiting=%s kv=%.1f%% preempt=%s\n",$2,$3,$4*100,$5}'
echo "tunnel events: $(grep -c reconnect $B/logs/tunnel.log 2>/dev/null)  shim errors: $(grep -c '"error"' $B/logs/shim.jsonl 2>/dev/null)"
awk '/wlp0s20f3/{printf "laptop rx=%.2fGB tx=%.2fGB (since start: rx %.2f / tx %.2f)\n",$2/1e9,$10/1e9,($2-1196228641)/1e9,($10-31898887)/1e9}' /proc/net/dev
