# laguna-bench — task set T1–T6 (Memsys / mem-mcp)

All validation on fresh DB clones (docker `lb-pg`), lead venv, `PYTHONPATH=<worktree>/src`.
Scorers: `bin/score_task.sh <Tn> <run_dir> <out>` (T1–T5), `bin/t6_score.sh <run_dir> <out>` (T6).
Self-test: every solution worktree scores PASS, every base worktree FAIL.

| Task | Category | Cx | Base | Solution | Hidden tests (F2P / P2P) | base → solution | Solution non-test diff | Rationale |
|---|---|---|---|---|---|---|---|---|
| T1 | pattern-conformant feature | standard | 2c6b590 | 67b15b7 | 35 (35 / 0) | 0 pass (ImportError) → 35 pass | +550/−0, 10 files | New admin MCP tool family must follow tool/service/audit/RBAC patterns (gate in base `__call__`, audit survives rollback, lint exemption). |
| T2 | multi-file root-cause bug | complex | 483763d | 8126500 | 21 (5 / 16) + 1 visible repro | 5 fail+16 pass, repro fails → all pass | +150/−66, 4 files (incl. migration 0035) | Symptom at plugin-SDK write; root cause in the references access rule, duplicated at sibling sites (hard-delete citers); P2P carve-out locks punish over-widening. Tests-only change = auto fail. |
| T3 | cross-cutting fix | standard | 67b15b7 | a68387f | 19 (15 / 4) | 15 fail → 19 pass | +138/−1, 5 files | Same authz gate across 3 tools + role-matrix consistency (owner missing from ROLE_PERMISSIONS); no-oracle + self-removal rules. |
| T4 | long-context feature | complex | 1b9ae6c | 8bb3100 (subset) | 25 (24 / 1), author-written | 24 fail → 25 pass | commit +1068/−17; in-scope ≈ 500 (needs a migration) | Branch status + mindmap_resolve + since/include/depth reads; hidden tests encode design-doc-only clauses (resolves-under / dropped-under edge vocabulary, archived = no-reopen, whose-turn open loops). |
| T5 | logic-heavy concurrency | complex | 10fd348 | author reference.patch | 15 (13 / 2), author-written | 13 fail (11/11 runs) → 15 pass (24/24 runs) | +90/−10, 4 files, no migration | Lost updates on memory_update (tag merge, forked version chains, blind overwrites); OCC revision token + DB-level serialization; real 6-way asyncio races vs Postgres. |
| T6 | test writing (mutation) | standard | 10fd348 | — | — (mutmut, 321 mutants) | floor 27.4% · original-commit tests 12.5% · author calibration 62.9% | — | memory_list + plugin notice pipeline; offline mutmut run ≈ 15 s; 3 real bugs at base available for "bugs found" credit. |

## Templates / migrations
- `bench_tpl` (alembic 0045, main) — T1, T3, T5, T6.
- `bench_tpl_t2` (0034 @ 483763d), `bench_tpl_t4` (0043 @ 1b9ae6c) — lower-case names (Postgres folds case).
  Helper: `bin/fresh_db_tpl.sh <template> <db>`.
- Migrations: T4 **requires** one (status columns); T2 reference adds one (pure-Python fix also valid); T5 optional.
  `score_task.sh` runs `alembic upgrade head` whenever meta `needs_migration != "no"`.

## Notes for the lead
- `score_task.sh` works on a `.git`-less copy of the run dir (never touches any git repo); `run_hidden.sh` restores overlaid files with `git checkout` only inside my own worktrees.
- T2's hidden `tests/unit/test_references_helpers.py` **replaces** an existing file at base (the commit extended it).
- T4/T5 hidden tests are author-written (validated against 8bb3100 / my reference); T1–T3 use the commits' own tests verbatim.
- known_red_base differs per base: T1–T3 48 ids, T4 49, T5/T6 32 (= known-red-online). Each base was run twice, with identical red sets.
- No flaky hidden tests seen (T5 stress-tested incl. 4-way parallel runs; see T5/validation.md).
- Real bugs on main found while building T6 (not fixed): memory_list cursor pagination crashes on any cursor (ISO string bound to timestamptz), skips the overflow row, and has a keyset tie-order mismatch.

## Rejected candidates
| Commit | Why not |
|---|---|
| 623eda9 memory_get_batch | Commit tests are input-schema unit tests only. T1 uses 67b15b7 instead. |
| bcb8e20 chunk_build backoff | Single-file fix + migration; tests are mock/SQL-string white-box (`"chunk_build_state" in sql`, positional args). |
| 4c5acf0 tenant GUC in system_tx | Only observable under RLS as a non-superuser; the test DB role is superuser, so no failing test is possible. |
| d007994, e135dd6, 1d1b7e6, 92ad1b8, 39d6567, 43a53c9 | No tests in the commit, or migration-only RLS fixes not observable as the superuser test role. |
| 1b9ae6c personal-team provisioning | Hidden tests import a new module (identity/personal_team) with mocks; 8126500 gives a cleaner symptom-only bug. |
| bc78aa1 plugin gate by role | Too small (≈30 lines, one file). |
| 8bb3100 as-is | 1085-line diff; white-box tests on private helpers spanning queue/answer verbs. Used a scoped subset with black-box tests (T4). |
| 7e89e9b mindmap core | Far too large (whole feature + 3 tables). |
| Early LLD-driven commits (4a2f118, ce1dace, f40f766, 74f2e7e …) | Doc-driven, but tests are AsyncMock call-order fixtures that dictate the implementation; the codebase was tiny then (little long context). |
| aaa5008 slug PK+retry (T5 history option) | Interface defined in an external memsys spec, not in the repo (reserved words, error classes, normalisation); only one concurrency test; needs a 0023 template. The backlog OCC task gives deterministic, mechanism-agnostic race tests. |
