#!/usr/bin/env bash
# laguna-bench — one-shot progress snapshot of an F2 solo run (read-only).  Usage: f2_status.sh <run_id>
RID="${1:-F2-2}"; B=$HOME/laguna-bench; R=$B/runs/$RID; cd $B
st=$(date -d "$(head -1 $R/master.started | cut -d' ' -f1)" +%s); echo "run $RID  elapsed $(( ($(date +%s)-st)/60 )) min  ($(date '+%H:%M IST'))"
echo "events: $(tail -n +2 $R/master.started | tr '\n' ' ')"
reqs=$(grep -c '"status"' logs/shim.jsonl); bad=$(grep '"status"' logs/shim.jsonl | grep -vc '"status": 200'); echo "shim log total requests: $reqs (non-200 lifetime: $bad); last: $(tail -n1 logs/shim.jsonl | grep -o '"t": [0-9.]*' | awk '{print $2}' | xargs -I{} date -d @{} +%H:%M:%S)"
[ -s $R/repo/docs/design/team-workflows.md ] && echo "design doc: $(wc -l < $R/repo/docs/design/team-workflows.md) lines" || echo "design doc: not yet"
[ -f $R/repo/QUESTIONS.md ] && echo "QUESTIONS.md present ($(grep -c '^[0-9]' $R/repo/QUESTIONS.md) numbered)"
(cd $R/repo && git add -A -n . 2>/dev/null | wc -l | xargs echo "files changed/added vs baseline:"; git status --short 2>/dev/null | grep -E '^\?\?|^ M' | awk '{print $2}' | head -12 | tr '\n' ' '; echo)
timeout 20 ssh -F ssh_config gpu 'curl -s 127.0.0.1:8000/metrics | grep -E "^llamacpp:(prompt_tokens_total|tokens_predicted_total)" | tr "\n" " "; echo; grep "draft acceptance" /opt/bench/llama.log | tail -1 | sed "s/.*draft acceptance/last draft acceptance/"' 2>/dev/null
python3 bin/token_ledger.py $RID | tail -n +2
