#!/usr/bin/env bash
# t6_mutmut.sh <tree> <outdir> [--only] [test paths/nodeids...]
# Mutation-score the T6 target modules. Copies <tree> (an executor run dir or worktree;
# .git/.venv/mutants excluded) to <outdir>/tree, writes a [mutmut] setup.cfg, clones a fresh
# DB from bench_tpl, runs `mutmut run` with the lead venv, and writes <outdir>/summary.txt.
# Test selection = BASELINE tests + given paths; with --only, just the given paths.
set -uo pipefail
src="$1"; out="$2"; shift 2
only=0; if [ "${1:-}" = "--only" ]; then only=1; shift; fi
BASELINE=(tests/unit/test_notice_delivery.py tests/unit/test_notice_client_serialization.py
          tests/unit/test_tools_list.py tests/unit/test_search_preview_lenient.py
          tests/unit/test_embedding_status_select.py)
sel=("$@"); [ $only = 0 ] && sel=("${BASELINE[@]}" "$@")
rm -rf "$out"; mkdir -p "$out/tree"
tar -C "$src" --exclude=.git --exclude=.venv --exclude=mutants --exclude=node_modules --exclude=web -cf - . | tar -C "$out/tree" -xf -
cd "$out/tree"
{ echo "[mutmut]"; echo "source_paths="; echo "    src/"
  echo "only_mutate="
  echo "    src/mem_mcp/plugins/notice_delivery.py"
  echo "    src/mem_mcp/plugins/clients/notices.py"
  echo "    src/mem_mcp/mcp/tools/list.py"
  echo "pytest_add_cli_args_test_selection="; for s in "${sel[@]}"; do echo "    $s"; done
  echo "pytest_add_cli_args="; echo "    -p"; echo "    no:cacheprovider"; echo "    -q"
} > setup.cfg
db="lb_mut_$$"
eval "$($HOME/laguna-bench/bin/fresh_db_tpl.sh bench_tpl "$db")"; export MEM_MCP_TEST_DSN MEM_MCP_DB_MAINT_DSN
unset PYTHONPATH
start=$(date +%s)
env -u AWS_PROFILE AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true \
  timeout 1500 $HOME/laguna-bench/wt/lead/.venv/bin/mutmut run > "$out/run.log" 2>&1
rc=$?; end=$(date +%s)
$HOME/laguna-bench/wt/lead/.venv/bin/mutmut results --all true > "$out/results.txt" 2>&1
docker exec -e PGPASSWORD=mem_test lb-pg psql -h localhost -U mem_test -d postgres -qtc "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" >/dev/null
{
  echo "mutmut rc=$rc runtime=$((end-start))s selection: ${sel[*]}"
  sed -E 's/__mutmut_[0-9]+:/:/' "$out/results.txt" | awk -F': ' 'NF==2{gsub(/^ +/,"",$1); print $1"\t"$2}' | sort | uniq -c
  total=$(grep -c "__mutmut_" "$out/results.txt"); killed=$(grep -c ": killed$" "$out/results.txt")
  echo "TOTAL mutants=$total killed=$killed kill_rate=$(python3 -c "print(f'{$killed/$total*100:.1f}%')")"
  echo "by status:"; awk -F': ' 'NF==2{print $2}' "$out/results.txt" | sort | uniq -c
} > "$out/summary.txt"
nc=$(grep -c ": not checked$" "$out/results.txt"); [ "$nc" != 0 ] && echo "WARNING: $nc mutants not checked (bad test selection or clean run failed) -- score invalid" >> "$out/summary.txt"
cat "$out/summary.txt" | tail -12
