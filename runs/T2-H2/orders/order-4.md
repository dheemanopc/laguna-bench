# Work order 4 — verification evidence (simple commands, no stash, no /tmp)

Run these as separate, simple commands (no `git stash`, no writing to /tmp, no `&&` chains)
and paste the literal output (trimmed to relevant lines):

1. `ruff check src tests`
2. `ruff format --check src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py tests/integration/test_references_access_rule.py`
   — if it would reformat, run `ruff format` on those files.
3. `mypy` — paste the summary line plus any errors mentioning the 4 files above. Fix errors in those
   files only.
4. `pytest -q -p no:cacheprovider tests -rfE` — paste the final summary line and the full list of
   `FAILED` / `ERROR` test ids from the short test summary.
5. For every failing/erroring test id from step 4, state whether it touches references, refs_in/out,
   user_effective_team_access, or memory write/get. For any that does, run it alone and show its
   failure reason, and explain why it is pre-existing (e.g. the failure is a fixture/email collision
   unrelated to our change). If you can, confirm by checking it with `git diff` reverted is not
   necessary — just reasoning plus the error text is fine.
6. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_rule.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py`
   — paste the summary line.
