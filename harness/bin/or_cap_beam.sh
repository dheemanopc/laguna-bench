#!/usr/bin/env bash
# or_cap.sh <baseline_usage> <cap_usd> <tmux sessions...>: stop the listed tmux sessions (and their Claude sessions, found by cwd)
# once OpenRouter account usage exceeds baseline+cap. Kills by PID only (never pkill -f).
B=$HOME/laguna-bench; B0=$1; CAP=$2; shift 2; SESS=("$@"); u=$B0
alive(){ for s in "${SESS[@]}"; do tmux has-session -t $s 2>/dev/null && return 0; done; return 1; }
while alive; do
  v=$(curl -s -m 20 https://openrouter.ai/api/v1/credits -H "Authorization: Bearer $(cat $B/.openrouter_key)" | jq -r '.data.total_usage // empty'); [ -n "$v" ] && u=$v
  if python3 -c "import sys;sys.exit(0 if $u-$B0>$CAP else 1)"; then echo "OR CAP hit usage=$u"
    for s in "${SESS[@]}"; do tmux kill-session -t $s 2>/dev/null; done
    for p in $(pgrep -x claude); do case "$(readlink /proc/$p/cwd)" in */runs/F2-10/*|*/runs/PL-G4/*|*/runs/PL-P4/*) kill $p;; esac; done
    break; fi
  sleep 60; done
date '+%H:%M %Z'; python3 -c "print('spent', round($u-$B0,3))"
