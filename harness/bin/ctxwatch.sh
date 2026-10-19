#!/usr/bin/env bash
# ctxwatch.sh <run_id> — live context of every running Laguna session (latest turn) + compaction count.
RD=$HOME/laguna-bench/runs/$1; P=$HOME/.claude/projects/$(echo "$RD/repo" | sed 's/[^a-zA-Z0-9]/-/g')
for f in $(find $P -name '*.jsonl' -mmin -10 2>/dev/null); do
  c=$(jq -c 'select(.message.usage) | .message.usage | (.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0)' "$f" 2>/dev/null | tail -1)
  k=$(grep -l "$(basename $f .jsonl)" $RD/t/*.meta.json 2>/dev/null | head -1); n=$(grep -c -E '"compact_boundary"|"isCompactSummary":true' "$f")
  echo "$(basename $f .jsonl | cut -c1-8) ctx=${c:-0} compactions=$n ${k:+done:$(basename $k .meta.json)}"
done
