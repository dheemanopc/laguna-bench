#!/usr/bin/env bash
# rc_session.sh <name> <cwd> <prompt_file> <out_json> <timeout_s> [--resume <session_id>] -- <claude flags...>
# Runs ONE Claude Code session INTERACTIVELY inside tmux with Remote Control enabled (`--remote-control <name>`),
# so Anand can watch it live on claude.ai/code or the mobile app. (Headless `claude -p` does not register
# Remote Control sessions — verified; interactive sessions do.)
#  - Permission mode dontAsk: anything not pre-approved by --allowedTools is denied, never prompts.
#  - A Stop hook (injected via --settings) writes the hook payload when the session finishes its turn;
#    the wrapper then reconstructs a `claude -p --output-format json`-like result from the transcript
#    (final text, session_id, per-model token usage de-duplicated by message id, turns) and kills the tmux session.
#  - Workspace-trust dialog for new run dirs is answered via tmux keystrokes.
# The caller passes environment (env -i ...) by exporting RC_ENV as a newline-separated list of VAR=value.
set -uo pipefail
NAME="$1"; CWD="$2"; PROMPT="$3"; OUT="$4"; TMO="$5"; shift 5
RESUME=(); if [ "${1:-}" = --resume ]; then RESUME=(--resume "$2"); shift 2; fi
[ "${1:-}" = -- ] && shift
B=$HOME/laguna-bench; W=$(mktemp -d -p $B/scratch rcs.XXXX)
SESS="rc-$(echo "$NAME" | tr -c 'a-zA-Z0-9_-' _ | cut -c1-60)"
# merge caller --settings JSON with our Stop hook (hooks are merged, so a caller PreToolUse path guard is kept)
ARGS=(); SET='{}'
while [ $# -gt 0 ]; do
  if [ "$1" = --settings ]; then SET="$2"; shift 2; else ARGS+=("$1"); shift; fi
done
SET=$(jq -c --arg cmd "cat > $W/stop.json" '.hooks = ((.hooks // {}) + {Stop:[{hooks:[{type:"command",command:$cmd}]}]})' <<<"$SET")
{
  echo '#!/bin/bash'
  echo "cd $(printf %q "$CWD") || exit 1"
  printf 'exec env -i'
  while IFS= read -r kv; do [ -n "$kv" ] && printf ' %q' "$kv"; done <<<"${RC_ENV:-}"
  printf ' claude --remote-control %q --permission-mode dontAsk' "$NAME"
  for a in "${RESUME[@]}"; do printf ' %q' "$a"; done
  for a in "${ARGS[@]}"; do printf ' %q' "$a"; done
  printf ' --settings %q' "$SET"
  printf ' "$(cat %q)"\n' "$PROMPT"
} > $W/launch.sh
chmod +x $W/launch.sh
tmux kill-session -t "$SESS" 2>/dev/null
tmux new-session -d -s "$SESS" -x 220 -y 60 "$W/launch.sh; sleep 5"
T0=$(date +%s); RC=0
while true; do
  if [ -s $W/stop.json ]; then
    if [ "$(jq -r '(.background_tasks // []) | length' $W/stop.json 2>/dev/null)" = 0 ]; then break; fi
    mv $W/stop.json $W/stop.bg.$(date +%s).json   # turn ended while waiting on a background task: keep waiting
  fi
  if ! tmux has-session -t "$SESS" 2>/dev/null; then RC=1; break; fi
  pane=$(tmux capture-pane -p -t "$SESS" 2>/dev/null)
  if grep -q "trust this folder" <<<"$pane"; then tmux send-keys -t "$SESS" Down; sleep 0.3; tmux send-keys -t "$SESS" Enter; fi
  [ $(( $(date +%s) - T0 )) -ge $TMO ] && { RC=124; break; }
  sleep 3
done
tmux capture-pane -p -S -200 -t "$SESS" > $W/pane.txt 2>/dev/null
RCURL=$(grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' $W/pane.txt | head -1)
tmux kill-session -t "$SESS" 2>/dev/null
SID=$(jq -r '.session_id // empty' $W/stop.json 2>/dev/null)
TP=$(jq -r '.transcript_path // empty' $W/stop.json 2>/dev/null)
if [ -z "$TP" ] && [ ${#RESUME[@]} -gt 0 ]; then SID="${RESUME[1]}"; fi
[ -z "$TP" ] && TP=$(ls -t $HOME/.claude/projects/*/"$SID".jsonl 2>/dev/null | head -1)
if [ -n "$TP" ] && [ -f "$TP" ]; then
  # usage of THIS invocation only: assistant messages after the last line count recorded at start is hard to know,
  # so we take messages whose timestamp >= start time.
  START_ISO=$(date -u -d @$T0 +%FT%TZ)
  jq -s --arg start "$START_ISO" --arg rc "$RC" --arg sid "$SID" --arg url "$RCURL" --slurpfile stop <(cat $W/stop.json 2>/dev/null || echo '{}') '
    [ .[] | select(.type=="assistant" and (.timestamp // "") >= $start) ] as $a
    | ($a | group_by(.message.id) | map(last)) as $msgs
    | {
        session_id: $sid, exit_code: ($rc|tonumber), remote_control_url: $url,
        is_error: (($rc|tonumber) != 0),
        num_turns: ($msgs | length),
        result: (($stop[0].last_assistant_message) // ([ $msgs[] | .message.content[]? | select(.type=="text") | .text ] | last) // ""),
        usage: { input_tokens: ([$msgs[].message.usage.input_tokens // 0]|add // 0),
                 output_tokens: ([$msgs[].message.usage.output_tokens // 0]|add // 0),
                 cache_read_input_tokens: ([$msgs[].message.usage.cache_read_input_tokens // 0]|add // 0),
                 cache_creation_input_tokens: ([$msgs[].message.usage.cache_creation_input_tokens // 0]|add // 0) },
        modelUsage: ($msgs | group_by(.message.model) | map({key: .[0].message.model, value: {
                 inputTokens: ([.[].message.usage.input_tokens // 0]|add), outputTokens: ([.[].message.usage.output_tokens // 0]|add),
                 cacheReadInputTokens: ([.[].message.usage.cache_read_input_tokens // 0]|add),
                 cacheCreationInputTokens: ([.[].message.usage.cache_creation_input_tokens // 0]|add)}}) | from_entries),
        thinking_blocks: ([ $a[] | .message.content[]? | select(.type=="thinking") ] | length),
        transcript: "'"$TP"'"
      }' "$TP" > "$OUT"
else
  jq -n --arg rc "$RC" --arg url "$RCURL" '{exit_code:($rc|tonumber), is_error:true, result:"", error:"no transcript", remote_control_url:$url}' > "$OUT"
fi
cp $W/pane.txt "${OUT%.json}.pane.txt" 2>/dev/null
rm -rf $W
exit $RC
