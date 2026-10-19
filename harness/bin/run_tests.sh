#!/usr/bin/env bash
# run_tests.sh <worktree> <template> <dbname> [--migrate] -- <pytest args...>
# Clones a fresh DB from <template>, optionally runs `alembic upgrade head` from the worktree,
# then runs pytest in the worktree with PYTHONPATH=<worktree>/src (worktree code, lead venv). Drops the DB after.
set -uo pipefail
wt="$1"; tpl="$2"; db="$3"; shift 3
migrate=0; if [ "${1:-}" = "--migrate" ]; then migrate=1; shift; fi
[ "${1:-}" = "--" ] && shift
eval "$($HOME/laguna-bench/bin/fresh_db_tpl.sh "$tpl" "$db")"
export MEM_MCP_TEST_DSN MEM_MCP_DB_MAINT_DSN
VENV=$HOME/laguna-bench/wt/lead/.venv
cd "$wt"
export PYTHONPATH="$wt/src"
if [ $migrate = 1 ]; then
  env -u AWS_PROFILE AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true \
    $VENV/bin/alembic upgrade head >/tmp/claude-1000/alembic_$db.log 2>&1 || { echo "ALEMBIC FAILED"; tail -20 /tmp/claude-1000/alembic_$db.log; }
fi
env -u AWS_PROFILE AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true \
  $VENV/bin/python -m pytest -q -p no:cacheprovider "$@"
rc=$?
docker exec -e PGPASSWORD=mem_test lb-pg psql -h localhost -U mem_test -d postgres -qtc "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" >/dev/null
exit $rc
