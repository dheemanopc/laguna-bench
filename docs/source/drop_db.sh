#!/usr/bin/env bash
docker exec -e PGPASSWORD=mem_test lb-pg psql -h localhost -U mem_test -d postgres -qtc "DROP DATABASE IF EXISTS \"$1\" WITH (FORCE)"
