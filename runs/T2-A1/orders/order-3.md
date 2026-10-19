# Work order 3 — finish verification without git stash

`git stash` is not permitted in your environment. Don't retry it, and don't use any other command
that rewrites the working tree or git state (no checkout, reset or worktree). Your working tree is
intact.

## A. Lint and types (step 7 from order 2)
Run each command on its own:
- `ruff check src tests`
- `ruff format --check src/mem_mcp/teams/references.py src/mem_mcp/mcp/tools/refs_in.py src/mem_mcp/mcp/tools/refs_out.py tests/integration/test_references_memory_readable_by.py alembic/versions/0035_2026_06_01_memory_readable_by.py`
- `mypy`

Fix findings in the files you changed. `ruff format <those files>` is fine. If mypy flags the
`# type: ignore[attr-defined]` comments as unused, replace them with
`assert isinstance(out, RefsInOutput)` / `RefsOutOutput` narrowing. If there are findings in files you
did *not* touch, list them as pre-existing and leave them.

## B. Show that the 50 full-suite failures are pre-existing
Without stash, do it by attribution:
1. Run `pytest -q -p no:cacheprovider tests -rfE 2>&1 | tail -80` and paste the full
   `FAILED`/`ERROR` id list, with a one-line reason for each.
2. For each failing or erroring test file, check whether it imports or exercises any of:
   `mem_mcp.teams.references`, `refs_in`, `refs_out`, `memory_readable_by`, the `write` tool's
   references path, or `alembic` revision heads (e.g. a test asserting the head revision is `0034`).
   Use grep plus reading the failure tracebacks.
3. Any failure whose traceback goes through code you changed, or that mentions `0035` /
   `memory_readable_by` / the head revision, must be investigated and fixed, without modifying
   existing tests. Report it explicitly.
4. Summarise: N failures, each classified as "unrelated pre-existing (reason)" or "caused by change
   (fixed)".

## C. Final re-run
- `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_memory_readable_by.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py`
- the full suite again (summary line).

Report the exact summary lines.
