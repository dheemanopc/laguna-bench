# Work order 5 — Full-suite failure triage (no code changes expected)

Since you cannot swap src files, do this instead:

1. Run the full suite once: `pytest -q -p no:cacheprovider -rfE 2>&1 | tail -80` and report the summary line and the full list of FAILED/ERROR node ids (with the one-line reason pytest prints).
2. For **every** failing/erroring test, classify it: does its failure involve `memory_update`, `MemoryUpdateTool/Input/Output`, `MemoryRecord`, `memory_get`/`memory_get_batch`, `compute_revision`, `versioning.py`, `tool_descriptions` or `FOR UPDATE`/locking (look at the traceback, e.g. rerun it individually with `pytest <nodeid> -q -p no:cacheprovider 2>&1 | tail -30`)? Report a table: node id → reason → related to our change (yes/no + why). For any that are tenants_email_key / fixture issues, one representative traceback is enough.
3. Also run any tests touching tool descriptions / tool registry / MCP schema (grep tests for `TOOL_DESCRIPTIONS`, `memory_update`, `inputSchema`, `tools/list`) and any web/plugin tests that touch update/get (grep tests for `MemoryUpdate`, `memory_update`, `MemoryRecord`, `memory_get`), list the files you ran and their results.
4. If anything is caused by our change, fix it in src (not by editing existing tests) and rerun.

Do not modify existing tests.
