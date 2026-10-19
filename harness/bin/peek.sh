#!/usr/bin/env bash
# peek.sh <run_id> [n_events=25]  — read-only view of what the run's CURRENT executor (Laguna/Sonnet) is doing,
# rendered from its live Claude Code transcript (thinking snippets, tool calls, results, text). Never touches the run.
RID="$1"; N="${2:-25}"; B=$HOME/laguna-bench; RD=$B/runs/$RID
P=$HOME/.claude/projects/$(echo "$RD/repo" | sed 's#[/.]#-#g')
TP=$(for f in $(ls -t $P/*.jsonl 2>/dev/null); do grep -q "You are the lead engineer (planner/reviewer)" "$f" || { echo "$f"; break; }; done); [ -z "$TP" ] && { echo "no executor transcript yet"; exit 0; }
echo "== $RID  orders=$(ls $RD/orders | wc -l)  executor calls done=$(ls $RD/exec/*.json 2>/dev/null | wc -l)  transcript=$(basename $TP)"
jq -r 'select(.type=="assistant" or .type=="user") | .timestamp[11:19] as $t |
  (.message.content | if type=="string" then [{type:"text",text:.}] else . end)[]? |
  if .type=="thinking" then "\($t) 💭 \(.thinking | gsub("\n";" ") | .[0:160])"
  elif .type=="tool_use" then "\($t) 🔧 \(.name) \(.input | (.command // .file_path // .pattern // (tostring)) | tostring | gsub("\n";" ") | .[0:150])"
  elif .type=="tool_result" then "\($t)    ↳ \(.content | tostring | gsub("\\\\n";" ") | .[0:110])"
  elif .type=="text" and (.text|length)>0 then "\($t) 💬 \(.text | gsub("\n";" ") | .[0:200])" else empty end' "$TP" | grep -v "system-reminder" | tail -n $N
