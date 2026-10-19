#!/usr/bin/env bash
# fresh_db_tpl.sh <template> <dbname> : (re)create a test DB cloned from the given migrated template; prints DSN exports
set -euo pipefail
tpl="$1"; db="$2"; sock="$HOME/laguna-bench/pgsock"
psql_() { docker exec -e PGPASSWORD=mem_test lb-pg psql -h localhost -U mem_test -d postgres -v ON_ERROR_STOP=1 -qtc "$1"; }
psql_ "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" >/dev/null
psql_ "CREATE DATABASE \"$db\" TEMPLATE \"$tpl\"" >/dev/null
echo "export MEM_MCP_TEST_DSN='postgresql://mem_test:mem_test@/$db?host=$sock'"
echo "export MEM_MCP_DB_MAINT_DSN='postgresql+psycopg://mem_test:mem_test@/$db?host=$sock'"
