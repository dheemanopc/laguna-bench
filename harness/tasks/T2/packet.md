# T2 — "memory_not_accessible" when citing my own memory

Category: multi-file root-cause bug · Complexity: complex · Time box: 90–120 min

## Symptom (as reported)

From the PMO plugin (it talks to Memsys through the in-process plugin SDK,
`mem_mcp.plugins`):

> I write memory M1. `memory_get(M1)` returns it fine. Then I write M2 with
> `references=[{target_uuid: M1, reference_kind: "cites"}]` and the write is
> rejected with `memory_not_accessible` ("reference target not found or not
> accessible"). M1 is mine — same account, I just read it.

It does not happen for every account. It reproduces reliably for users whose
account was provisioned the "natural" way — tenant, personal team, owner
assignment and primary identity created by raw SQL (this is how the 0026
personal-team backfill provisioned all pre-existing users) — rather than
through the team-management API. It started after the teams/references work
landed (migrations ~0024–0026).

A failing repro is provided:
`tests/integration/test_references_own_memory_repro.py` (already in your
working tree). It must pass when you are done.

## What we expect

- A user can always reference (and otherwise act on, via the references
  machinery) memories they can read. Write-time access checks for references
  must agree with the read path — i.e. with what `memory_get` lets the caller see.
- Find the root cause rather than special-casing the write call. If the
  faulty rule is evaluated in more than one place, every such place must be
  fixed and behave consistently — hidden regression tests cover more than the
  repro.
- Cross-tenant protection must not regress: referencing another tenant's memory
  that you have no team access to is still rejected with the same **opaque**
  `memory_not_accessible` error envelope (not-found and no-access stay
  indistinguishable).
- Slug-based lookups that are resolved *before* the target is known
  (`memsys_slug_lookup`, `memory_get` by slug, `memory_get_batch` by slug) gate
  at the team level on purpose — it prevents slug enumeration in teams the
  caller cannot see. Do **not** change those.

## Constraints

- Follow existing patterns. If you need a database-side helper, schema changes
  go through a new Alembic migration in `alembic/versions/` (follow the naming
  and the `SECURITY DEFINER` / `NULLIF`-guarded GUC conventions used by the
  existing RLS helper migrations). The scoring harness runs
  `alembic upgrade head` on a fresh database before running tests.
- A fix that only changes tests is an automatic fail. Do not modify existing
  tests; add regression tests of your own for each site you change.
- The rest of the suite must not get new failures (some tests are red before
  you start — pre-existing; leave them).

## Running tests

`MEM_MCP_TEST_DSN` points at a fresh migrated Postgres (if you add a migration,
apply it with `alembic upgrade head`; `MEM_MCP_DB_MAINT_DSN` is set for that).
Run the repro with
`pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py`
and the wider suite with `pytest -q -p no:cacheprovider tests`.
The `sdk_client_factory` fixture (`tests/integration/conftest.py`) builds a
plugin-SDK client bound to a tenant.
