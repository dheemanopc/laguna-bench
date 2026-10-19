#!/usr/bin/env bash
# shadow_reviews.sh <run_id> — sidecar for a run_staged.sh run (Anand 2026-10-16: "keep an eye on what a sonnet subagent can do").
# Whenever the Opus architect starts a gate review ('review <st> round <r> start' in master.started), run a SONNET session on
# the IDENTICAL prompt, writing to orders/shadow-<st>-<r>.md instead. Shadows are never sent to the engineer: the run is
# unaffected. Read-only (same tool restrictions as the architect). Compare later: verdict agreement, findings overlap, cost.
# Caveat: the engineer resumes as soon as Opus answers, so a slow shadow may read a slightly newer tree.
RID="$1"; B=$HOME/laguna-bench; RD=$B/runs/$RID; done_list=$RD/orders/.shadowed
touch $done_list
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
export RC_ENV="$(printf '%s\n' HOME=$HOME USER=$USER LANG=C.UTF-8 TERM=xterm-256color "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 DISABLE_AUTOUPDATER=1)"
while [ ! -f $RD/master.summary.json ]; do
  grep -o -E 'review [a-z0-9]+ round [0-9]+ start' $RD/master.started | while read -r _ st _ r _; do
    key="$st-$r"; grep -qx "$key" $done_list && continue
    p=$RD/orders/review-$st-$r.prompt.md; [ -f $p ] || continue
    echo "$key" >> $done_list
    sed "s#$RD/orders/review-$st-$r.md#$RD/orders/shadow-$st-$r.md#g" $p > $RD/orders/shadow-$st-$r.prompt.md
    echo "$(date -u +%FT%TZ) shadow $key start" >> $RD/orders/shadow.log
    ( $B/bin/rc_session.sh "lb-$RID-shadow-$st-$r" "$RD/repo" "$RD/orders/shadow-$st-$r.prompt.md" "$RD/shadow-$st-$r.json" 1800 -- \
        --model sonnet --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
        --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
        --disallowedTools "Edit(/$RD/repo/**)" Bash WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree \
        2> $RD/shadow-$st-$r.stderr
      echo "$(date -u +%FT%TZ) shadow $key: $(head -1 $RD/orders/shadow-$st-$r.md 2>/dev/null)" >> $RD/orders/shadow.log ) &
  done
  sleep 15
done
