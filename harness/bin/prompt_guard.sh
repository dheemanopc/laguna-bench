#!/usr/bin/env bash
# prompt_guard.sh — single watcher for all bench tmux sessions (rc-lb-*): if an interactive permission/approval
# dialog is showing at the BOTTOM of the screen, press Escape once (= deny, what dontAsk / headless -p would do)
# and log it. Never acts on text elsewhere in the scrollback; 10 s cooldown per session to avoid stray Escapes
# (a stray Escape would interrupt the agent).
B=$HOME/laguna-bench; declare -A last
while true; do
  for s in $(tmux ls -F '#S' 2>/dev/null | grep '^rc-lb-'); do
    bottom=$(tmux capture-pane -p -t "$s" 2>/dev/null | grep -v '^\s*$' | tail -12)
    if grep -q -E "Do you want to (proceed|make this edit|create|allow)|Would you like to proceed" <<<"$bottom" && grep -q -E "Esc to cancel|❯ 1\.|1\. Yes" <<<"$bottom"; then
      now=$(date +%s); [ $(( now - ${last[$s]:-0} )) -lt 10 ] && continue
      tmux send-keys -t "$s" Escape; last[$s]=$now
      echo "$(date -u +%FT%TZ) HARNESS: $s auto-denied prompt: $(grep -m1 -E 'Do you want|Would you like' <<<"$bottom" | cut -c1-120)" >> $B/logs/harness_events.log
    fi
  done
  sleep 3
done
