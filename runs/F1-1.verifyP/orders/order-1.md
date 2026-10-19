You are an independent VERIFICATION engineer. Another team delivered the code in this repository. Execute the
verification plan below against it and report honestly. Rules: do NOT modify anything under src/, alembic/ or
existing tests — you may only ADD new test files under tests/verify/ (and a conftest there if needed). Run the
checks yourself (pytest, alembic upgrade head, ruff check src tests, mypy). Pre-existing failures are listed in
KNOWN_RED_BASE.txt. Nobody will answer questions. Write VERIFY_REPORT.md in the repository root: for every check
V1..Vn: PASS / FAIL / NOT RUN, the exact command you ran and the relevant output lines; then a list of defects
found (with file:line), and an overall verdict. A FAIL that shows a real defect is a good outcome — do not fix it.

=== VERIFICATION PLAN ===
# VERIFICATION PLAN — F1 work items, WP1 (migration 0046 + service) and WP2 (four write tools)

Sources: BRIEF.md (AC = acceptance criterion numbers), DESIGN.md (D§), CONVENTIONS.md (C§).
Round-1 scope per D§5: AC1–6, 8–12, 13–14, 15–19, 25–26, 28, 21, 30; service-level data for 22–24, 27, 29.
Tools in scope: `mindmap_work_mark`, `mindmap_work_set_status`, `mindmap_work_set_kind`, `mindmap_work_assign`.
NOT in scope this round (do not fail for absence): `mindmap_work_list`, `mindmap_work_history` tools, `mindmap_get` embedding, web endpoints, SPA.

## Ground rules for the verifier
- Do not edit `src/` or existing tests. Add new tests only under `tests/verify/` (create `__init__.py`/conftest if needed; reuse the `pg_pool` fixture and the fixture style from `tests/integration/test_mindmap_e2e.py`).
- Drive behaviour **through the public tool classes** (`ToolContext` + `Tool().__call__` or the `ToolRegistry`) for WP2 checks and through the service module (`src/mem_mcp/mindmap/work_items.py`) for WP1 checks. Read the code only to discover names/signatures; judge by observable behaviour (return values, error code+data, DB rows).
- Use UUID-suffixed emails/names. Do not assume empty tables.
- For every rejection check, assert **both** the error (type/code/message content) **and** that DB state is unchanged: row in `work_items` identical (incl. `updated_at`, `status_changed_at`) and `count(*) from work_item_history where memory_id=…` unchanged, and no new `memory_map_events` row.
- Direct DB inspection should use a maintenance/superuser connection (`MEM_MCP_DB_MAINT_DSN`) for ground truth, and the app role (via `tenant_tx`) for RLS/grant checks.
- Record each V as PASS/FAIL with evidence (test name + assertion/output). Any FAIL in a **[BLOCKER]** check = round fails.

## Shared test fixture (build once, `tests/verify/conftest.py`)
Create, via real DB rows (as in test_mindmap_e2e):
- Tenant/team **T1** with users: `owner_u`, `admin_u`, `member_u`, `bot_u` (service-bot role if the roles catalog has it), `viewer_u`, `vendor_u`; `outsider_u` (own tenant, not on T1); `removed_u` (member then removed). Tenant **T2** with its own team/user (`other_tenant_u`).
- Map **M_live** (live) in T1 with root R and nodes A, B, C, D, E (plain nodes, various types); map **M_arch** (closed/archived via the real close path) with root and node X (created before closing), plus a work item on it created before archive; a second live map **M2** in T1 with node Z.
- A node in M2 (Z) used for "node not in named map" checks.
- Helper to call each tool as a given user and to fetch `work_items` / `work_item_history` / `memory_map_events` / `memories` / `memory_map_membership` rows.

---

## A. Project gates

**V1 [BLOCKER] Alembic single head, migration applies and reverses.**
Covers C§Migrations. Run `alembic heads` → exactly one head, and it is the new 0046 revision (file `alembic/versions/0046_*.py` with docstring explaining why, `down_revision` = previous head, `downgrade()` present). Run `alembic upgrade head` (no-op if already). Then on a *scratch copy only if feasible* (otherwise skip and say so): `alembic downgrade -1 && alembic upgrade head` succeeds. Check `alembic check`/autogenerate is not required.

**V2 [BLOCKER] Lint & types.** `ruff check src tests` and `ruff format --check` on new/changed files; `mypy` (project config). Compare against baseline: any error located in a new/changed file is FAIL; pre-existing errors elsewhere are noted, not failed. To get baseline, list changed files by mtime/`grep -rl work_item src tests alembic` and examine only those.

**V3 [BLOCKER] Full suite vs. pre-existing failures.** Run `pytest -q -p no:cacheprovider` on the delivered tree and record failures. Then determine whether each failure is pre-existing: the failing tests must be ones that collide on hard-coded emails/fixtures and do not touch work items/mindmap tools code paths changed; confirm by re-running a failing test in isolation, and by `git stash`-free means (e.g. inspect the failure message; if it concerns work_item/mindmap/tool registry/audit, it is NEW). Specifically must be green: `tests/unit/test_lint_tenant_scope.py` (esp. `test_real_codebase_is_clean`), all existing mindmap tests (`tests/**/test_mindmap*`), tool-registry / tool-description / tool-listing tests, audit-action tests, and any test enumerating tools or migrations. Report the list of red tests with a one-line cause each. New failure = FAIL.

**V4 [BLOCKER] Tenant-scope lint on the new code.** Run `python tools/lint_tenant_scope.py` (see how the unit test invokes it). Must be clean. Then manually read every SQL statement in `mindmap/work_items.py`: each statement on `work_items` / `work_item_history` must carry an explicit `tenant_id = $n` predicate (defence in depth, C§Database). Any exemption added to the lint exempt-list for the new module without a justification comment = FAIL.

**V5 Delivered new tests are meaningful.** The developers' own new tests (unit for WP1, e2e for WP2) exist, pass (`pytest <their files> -q`), and assert behaviour (state + errors), not merely "no exception". Not a blocker by itself; note quality. They must not have modified/deleted/skipped any pre-existing test (check by comparing test file mtimes / grep for new `skip`/`xfail` markers in pre-existing files; `git diff` is unavailable so inspect carefully).

## B. Schema, RLS, append-only (AC21, AC28, AC29, D§1)

**V6 [BLOCKER] Schema matches design.** With a maint connection, inspect `information_schema`/`pg_catalog`:
- `work_items`: PK `memory_id` → FK memories ON DELETE CASCADE; `root_memory_id` FK `memory_maps(root_memory_id)`; `tenant_id`, `team_id` FKs; CHECK on kind ∈ {story,epic,milestone}; CHECK status ∈ the five; default status `todo`; `assignee_id` nullable with **no FK**; timestamptz columns with defaults; the three indexes.
- `work_item_history`: `id` bigserial PK, FKs, `change_type` CHECK ∈ {created,status,owner,kind}, `actor_id NOT NULL`, `channel NOT NULL CHECK IN ('mcp','web')`, `reason` nullable, `created_at timestamptz NOT NULL` defaulting to `clock_timestamp()`, and the snapshot columns (`kind_before/after`, `status_before/after`, `assignee_before/after`) per the design's FINAL decision. Attempt direct inserts as superuser violating each CHECK (kind 'task', status 'open', channel 'cli', change_type 'x') → each must raise a check violation (and clean up).
- `memories`, `memory_map_membership`, `memory_maps` have no added/changed columns vs. 0045 (inspect the migration file for ALTERs on those tables → must be none) (AC7, additive).

**V7 [BLOCKER] History is append-only for the application role (AC28).** Connect as the app role via `tenant_tx` (the same role the tools use; if the test DB's role is a superuser/BYPASSRLS, instead assert on `information_schema.role_table_grants` / `has_table_privilege('mem_app','work_item_history','UPDATE'|'DELETE')` = false and `'SELECT'|'INSERT'` = true). Attempt `UPDATE work_item_history SET reason='x'` and `DELETE FROM work_item_history` as the app role inside a tenant_tx with the tenant that owns rows → must raise `InsufficientPrivilege` (or affect 0 rows with no policy) and rows remain intact. Same for `TRUNCATE`. Also: `work_items` has no DELETE grant for mem_app; has SELECT/INSERT/UPDATE. Also verify there is no UPDATE/DELETE RLS policy on history (`pg_policies`). Team admin identity must make no difference (no code path): grep `src/` for `DELETE FROM work_item_history|UPDATE work_item_history` → none.

**V8 [BLOCKER] RLS tenant isolation (AC21).** Create work items in T1 (with history). Under `tenant_tx(pool, T2)` as app role: `SELECT count(*) FROM work_items`/`work_item_history` where memory_id in T1's items → 0; `UPDATE work_items SET status='done' WHERE memory_id=…` → 0 rows; `INSERT` into work_items/history with `tenant_id=T1` → rejected by WITH CHECK. With no tenant GUC set (plain connection / after a ROLLBACK where GUC reads `''`) → SELECT returns 0 rows and does not error with a uuid-cast error (RLS uses `safe_current_tenant_id()`; confirm in the migration policies). `ENABLE ROW LEVEL SECURITY` is on for both tables (`pg_class.relrowsecurity`); consider FORCE per peer pattern (note, not fail).

**V9 [BLOCKER] Cross-tenant through the tools (AC21, AC20).** As `other_tenant_u` (T2), call all four write tools against T1's map/node IDs (including with a `team_id` argument pointing at T1's team): every call returns the **identical opaque not-found** as for a nonexistent map (compare `code`, `message`, `data` with a call using a random UUID/unknown map_key; must be byte-equal apart from request id) and T1 state/history is unchanged.

## C. Marking (AC1–7)

**V10 [BLOCKER] Happy path marking, each kind (AC1, AC25).** As `member_u` (also repeat as `owner_u`, `admin_u`; and `bot_u` if the role is in the catalog — design says it holds write): mark A=story, B=epic, C=milestone, one with `assignee_id=member_u` and the others unassigned. Expect: output reports kind, status `todo`, assignee, node id; `work_items` row: status `todo`, kind, assignee, `tenant_id`/`team_id`/`root_memory_id` equal to the map's, `created_by`=caller, `status_changed_at`≈`created_at`. Exactly **one** `work_item_history` row per item: `change_type='created'`, `actor_id`=caller, `channel='mcp'`, `created_at` not null, `*_before` all NULL, `kind_after`=kind, `status_after`='todo', `assignee_after`=assignee-or-NULL, `reason` = given text or NULL. One `memory_map_events` row (event `work_item`, actor `model`) per mark.

**V11 [BLOCKER] Invalid kind (AC2).** kind ∈ {`task`, `Story`, `''`, `bug`}: rejected with `-32602`-style structured error (`data.errors[]`), message names all of `story`, `epic`, `milestone`; no row, no history, no event. (If the input model's Literal rejects it before service, the error must still list the allowed kinds — check message text, not only the path.) Also check `extra="forbid"`: an unknown field is rejected.

**V12 [BLOCKER] Root node rejected (AC3).** node_id = map root → rejected with a clear message ("root"…), nothing inserted. Check at service level too (calling `work_items` service directly with the root id must raise the service's own exception, not rely on the tool).

**V13 [BLOCKER] Already a work item (AC4).** Mark A (story, assignee member_u), then mark A again as epic with another assignee: rejected; row unchanged (kind story, assignee member_u, same `updated_at`); history still exactly 1 row.

**V14 [BLOCKER] Archived map (AC5, AC18).** Mark node X on M_arch → rejected with a map-not-live style error (compare with existing `map_not_live` -32602 code if the tool reuses it; any structured -32602 with clear text OK); nothing inserted. Contrast: marking a node on a live map still works (V10).

**V15 [BLOCKER] Node not in named map (AC6).** (a) node Z (member of M2) with map_key of M_live; (b) random UUID; (c) a node id that is a plain `memories` row not in any map; (d) node that exists in a different tenant. All rejected as NotInMap/not-found; nothing inserted. (d) must not reveal existence (same response as (b)).

**V16 [BLOCKER] Marking leaves the map untouched (AC7, AC13).** Snapshot before/after for the marked node and its map: `memories` row (content, type, all columns incl. `updated_at`), `memory_map_membership` row (branch status, turn, etc.), edges/links. After marking, these are byte-identical. Then call the existing tools `mindmap_get`, and the existing branch tools (resolve / drop branch on a work node's branch): outputs equal the pre-feature shape and the work item `status` is unchanged afterwards (AC13). Then change work status (todo→in_progress) and verify branch status/turn unchanged (AC13 reverse direction). If `mindmap_get` already exposes `work_item` (WP3 not due), that is not a failure, but plain nodes' output must be unchanged.

**V17 Assignee validation on mark (AC16 at creation).** assignee ∈ {viewer_u, vendor_u, outsider_u, other_tenant_u, removed_u, random uuid, bot_u (per design D§0 not assignable)} → rejected with an error that identifies the assignee problem; no row/history. Valid: owner/admin/member. Assignee given as blank string or invalid UUID → structured -32602.

## D. Status transitions (AC8–12)

**V18 [BLOCKER] Full transition matrix (AC8, AC9, AC10, AC11).** Parametrised exhaustive test over all 5×5 (from,to) pairs (25 cases). For each, put a fresh work item into `from` through legal paths (todo→in_progress→blocked, →done, cancelled; use reasons where required), then request `to` **without reason** and with reason `"because"`:
- Allowed set exactly: todo→in_progress (no reason), todo→cancelled (reason), in_progress→blocked (reason), in_progress→done, in_progress→todo, in_progress→cancelled (reason), blocked→in_progress, blocked→cancelled (reason), done→in_progress (reason), cancelled→todo (reason). Write this table in the test independently from the dev code (do not import the dev's table).
- Allowed & reason not required: succeeds both without and with reason. Allowed & reason required: without reason, with `""` and with `"   "` (blank) → rejected, status unchanged, no history; with reason → succeeds.
- Not in table (15 pairs incl. same-status pairs): rejected both with and without reason; status unchanged; no history; error message contains the current status and requested status strings (AC9). Same-status error is rejected (AC11). Explicitly named cases: blocked→done, todo→done, cancelled→in_progress, done→todo, done→cancelled, todo→blocked.
- On success: output new status; `work_items.status` = requested; `status_changed_at` advanced (≥ previous) and `updated_at` set; exactly one new history row (`change_type='status'`, `status_before`/`status_after` correct, `kind_*`/`assignee_*` snapshot columns equal to the unchanged current values, `actor_id`, `channel='mcp'`, `reason` as given (trimmed/None for blank on optional-reason transitions)).
Check order from D§2: invalid status value → expected mismatch → same-status → not-in-table → reason required. Add targeted tests: (i) blocked→done without reason yields the **transition** error (not "reason required"); (ii) todo→todo with expected_status='done' yields the **mismatch** error.

**V19 [BLOCKER] Invalid status value.** status ∈ {`open`,`DONE`,`wip`,`''`}: structured -32602 error naming allowed statuses; nothing changes.

**V20 [BLOCKER] expected_status guard (AC12).** Item in `in_progress`. Call set_status to `done` with `expected_status='todo'` → rejected; message/data reports actual current status `in_progress`; status unchanged; no history. With `expected_status='in_progress'` → succeeds. With invalid expected_status value (`'foo'`) → structured error, no change. Without expected_status → still works.

**V21 [BLOCKER] Concurrency guard (D§2 FOR UPDATE; AC12 intent).** Two concurrent `set_status` calls on the same item in `in_progress` (via `asyncio.gather`, separate pool connections): A→`done`, B→`blocked` with reason. Exactly one succeeds, the other is rejected (since done→blocked / blocked→done are not in the table, whichever goes second fails with a transition error naming the status the first one wrote). Final state consistent with exactly one history row added; history chain is continuous (`status_before` of row n == `status_after` of row n-1). Second scenario: both callers pass `expected_status='in_progress'` and the same target `done` ... exactly one success, the other gets a mismatch/same-status error; never two history rows with identical before/after. Repeat the race 20 times to reduce flakiness. Also grep the service for `FOR UPDATE` on the work_items read in set_status/set_kind/assign (read-modify-write must not be unlocked). Same race for set_kind (A→epic vs B→milestone) and assign: history chains must remain continuous.

**V22 Reason handling.** Reason of 2000 chars accepted; 2001 chars rejected (-32602) with no change; blank/whitespace reason treated as absent (stored NULL, not `"   "`); reason with unicode/newlines stored verbatim (modulo trim).

## E. Kind and owner changes (AC15–17)

**V23 [BLOCKER] Change kind (AC17).** story→epic, epic→milestone, milestone→story all succeed (reason optional); each adds exactly one history row `change_type='kind'`, `kind_before/after` correct, status/assignee snapshot unchanged. Same kind → rejected, no history. Invalid kind (`task`) → rejected naming allowed kinds. Status and assignee unchanged by kind change.

**V24 [BLOCKER] Assign / reassign / unassign (AC15, AC16, AC30-prep).** member assigns item to admin_u → `assignee_id` immediately visible (re-read via service read function and DB); reassign to owner_u; unassign (`assignee_id=null`) → NULL. Each success = exactly one history row `change_type='owner'` with `assignee_before/after` correct (NULL ↔ uuid) and unchanged status/kind snapshot. Assign to the same current assignee, and unassign an already-unassigned item → must be rejected as no-op **or** at minimum add no history row (document which; a history row for a no-op is FAIL). Assign to viewer_u, vendor_u, outsider_u, other_tenant_u, removed_u, random UUID, bot_u → rejected, owner unchanged, no history. Distinguish the omitted `assignee_id` case: if the field is omitted (not null) the tool must reject it as missing rather than silently unassign (check InputModel: required but nullable).

**V25 Assignee later removed from team (AC30).** Assign item to `removed_u`'s precursor while still a member; then remove them from the team via the real assignment-removal code/SQL (`team_role_assignments`; refresh `user_effective_team_access` as the code does). Then: `work_items.assignee_id` still equals them; history still lists them; status changes and kind changes on that item by other members still work (no read-time membership check); reassigning to someone valid works; re-asserting assignment to the removed person is rejected.

## F. Permissions, opacity, error mapping (AC19, AC20, AC31)

**V26 [BLOCKER] Viewer/vendor denied on every write (AC19).** `viewer_u` and `vendor_u` call each of the four tools on valid targets (existing work item / unmarked node on live map): each returns the RBAC permission error (per C§Error model: `-32603` with `data.missing_permission` = the team write-memory permission string `TEAM_WRITE_MEMORY` value) — consistent with how existing mindmap write tools deny viewers (compare with an existing tool's viewer denial and require same code/shape). State, history, events unchanged. Importantly, viewer on an **unknown node/invalid input** should get the permission error not an input-detail error (check order: role → permission → state → node rules). Verify with invalid kind as viewer → permission error.

**V27 [BLOCKER] Non-member opacity (AC20).** `outsider_u` (same tenant? or different — test both: a user in another team of the same tenant if constructible, plus T2 user) calls all four tools with a real map_key: response identical (code, message, data shape) to the response for a nonexistent map_key. Must hold for mark / set_status / set_kind / assign, with valid and invalid payloads (invalid kind still yields the opaque not-found, not a validation error that leaks existence). Also confirm no audit/other side-effect rows were written for them.

**V28 [BLOCKER] Archived map allows changes (AC18).** On M_arch's pre-existing work item (created before the map was closed): set_status todo→in_progress→blocked (with reason), set_kind, assign, unassign all succeed, produce history rows. Also done→in_progress with reason. Viewer is still denied on archived map. Creating a new one still fails (V14).

**V29 [BLOCKER] Map close leaves items unchanged (AC14, AC13).** On a live map with work items in mixed statuses/kinds/assignees, close the map using the real close code path (and with a graduation if the test setup supports it). Compare `work_items` rows (status, kind, assignee, `status_changed_at`, `updated_at`) before/after: identical; `work_item_history` row count identical. Also resolve/drop branches containing work nodes → no change in work_items/history.

**V30 [BLOCKER] Error mapping style (AC31).** For each failure class, assert JSON-RPC code/data via the tool (not service): validation errors (bad kind/status/UUID/missing field/extra field/over-long reason) → `-32602` with `data.errors[{path,message}]`; not found/not in map/root/already work item/not live/transition illegal/reason required/same status/expected mismatch/invalid assignee → `-32602` (with a specific `data.code` where the existing pattern uses one) and a human-readable message that mentions the relevant values; RBAC → `-32603` + `missing_permission`; nothing leaks as `-32603 internal error`/HTTP 500/uncaught exception. Fuzz a few malformed payloads (null node_id, node_id not UUID, map_key empty, status of wrong JSON type, `team_id` of other team the caller isn't in) → structured error, never an uncaught exception. Service layer must not import `JsonRpcError`/FastAPI: `grep -n "JsonRpcError\|fastapi" src/mem_mcp/mindmap/work_items.py` → none (C§Layering).

**V31 team_id parameter.** With `team_id` given and the map belonging to another team (even one the caller can read) → map not found (opaque), no write. With `team_id` equal to the map's team → works. Omitted `team_id` → uses the caller's default team; confirm behaviour mirrors existing mindmap tools.

## G. Audit trail (AC25–29)

**V32 [BLOCKER] Exactly-one-row invariant & rejected attempts add none (AC25, AC26).** Property-style test: run a random sequence (seeded, ≥200 ops) of mark/set_status/set_kind/assign calls mixing valid and invalid input from members/viewers on a handful of items; after every call assert `Δ history rows == 1` if the call succeeded and `0` otherwise, and that the current `work_items` row equals the last history row's `*_after` snapshot (AC27) — all three of kind/status/assignee.

**V33 [BLOCKER] History completeness for the 8 audit questions (AC29, brief 4.4).** After a scripted lifecycle (mark with assignee A → in_progress → blocked "waiting on X" → in_progress → reassign B → kind change → done → reopen with reason → cancelled with reason → revive), read history via the service's history read function ordered by `id`/`created_at` and prove from the rows alone: current state & since when; who marked and when; who set done and via what channel; owner at an arbitrary past timestamp (compute from rows, compare to ground truth recorded by the test); reasons for blocked/cancelled/reopened; time in each status (sum of intervals; all `created_at` strictly non-decreasing and `id` strictly increasing; chain continuity `*_before(n) == *_after(n-1)` for status, kind, assignee); per-actor filter (use two actors); channel is `mcp` for tool-driven changes. Service read returns oldest-first (AC27).

**V34 Timestamps.** History `created_at` is `clock_timestamp()` (distinct for rows written in one transaction — e.g. mark + assign inside the same tx via service calls have distinct, ordered timestamps); `work_items.status_changed_at` changes only on status change (not on kind/assign), `updated_at` changes on every change.

**V35 Service-level list/read (D§5 "service-level data for 22–24").** If the service exposes list/history/get functions: list per map and team-wide with filters status/kind/assignee/unassigned/assigned_to_me/map_state; confirm plain nodes never appear, items on archived maps appear unless map_state='live' filter, items from other teams/tenants/inaccessible teams never appear, result includes kind/status/assignee/title (from node content)/map/updated time. A user with no team role gets opaque not-found (map-scoped) or an empty result (team-wide). Non-blocking for pass/fail if absent from the API but a defect if present and wrong.

**V36 [BLOCKER] Channel and actor from context.** Tool writes `channel='mcp'` always, `actor_id` = authenticated `ctx.identity_id`/tenant per design D§0 (not an input field). Verify that no tool input accepts `actor`, `channel`, or `tenant_id` overrides (extra="forbid" rejects them) — a caller must not be able to forge actor/channel. A service-level call with channel `'web'` is stored as `'web'` with event actor `owner`.

**V37 Map events (D§10).** Each successful write appends a `memory_map_events` row (event `work_item`) in the same transaction; rejected attempts add none; existing `mindmap_get since=` still works and returns unchanged output for old consumers (the unknown event type must not crash existing readers — run the existing tests for `mindmap_get since` and also call it after a work event with a cursor taken before it).

**V38 Transactionality / atomicity.** Inject a failure after the item write (e.g. monkeypatch the audit logger or event writer to raise) inside `tenant_tx`; after rollback there must be no orphaned `work_items` row or history row (and vice-versa no history without row). Audit: successful tool calls call `ctx.deps.audit.audit` with a new `AuditAction` member (present in the `AuditAction` Literal in `audit/logger.py`); use `DbAuditLogger` in one test and check an `audit_log` row appears with `result` success and `details` free of node content / reason text (C§Audit — no content logging; ids only). Rejected permission/not-found attempts follow the existing pattern for other mindmap writes.

## H. Registration, descriptions, conventions

**V39 [BLOCKER] Registration & scope.** All four tools are registered in `main.py` (grouped by family with comment), discoverable via `tools/list` through the real `ToolRegistry`; names exactly `mindmap_work_mark`, `mindmap_work_set_status`, `mindmap_work_set_kind`, `mindmap_work_assign`; `required_scope == "memory.write"` for each; a token with only `memory.read` scope calling them gets `-32000` `insufficient_scope` (via registry dispatch). Input JSON schemas expose `kind`/`status` enums. `mindmap_work_list`/`history` absence is fine.

**V40 Descriptions & style.** `TOOL_DESCRIPTIONS` has entries for all four in house style ("Call when:", "Do not call for:", "Examples:"), the description of set_status documents the transition rules / reason requirement / expected_status; descriptions use "assignee" wording to avoid confusion with owner/turn (brief 4.1). Tool classes follow C§MCP tools: `assert isinstance(inp, …)`, `<Tool>Input/<Tool>Output`, `request_id=ctx.request_id`. Existing test that checks every registered tool has a description / matching schema must pass (covered by V3).

**V41 No regression of existing mindmap behaviour (AC7).** Run `pytest -q tests -k "mindmap or map"` and explicitly the e2e `test_mindmap_e2e.py`; all pre-existing passing tests still pass. Additionally, snapshot test on a map with no work items: outputs of `mindmap_get`/other existing tools are byte-identical in structure to the pre-change output (no new keys at top level or per-node unless optional and absent for non-work nodes).

**V42 Unit test of pure helper.** `check_transition(current, requested, reason)` exists (D§2) and is exercised directly on the 25×{no reason, blank, reason} matrix returning/raising per V18 (service-level, no DB); raises the service's own exception types, not generic `ValueError`/HTTP/JsonRpc types, and error text includes both statuses.

---

## Verdict rules
- PASS only if **all [BLOCKER]** checks pass and no new test failures vs. baseline (V3), ruff/mypy clean on touched files (V2), single alembic head (V1).
- Non-blocker failures (V5, V17, V22, V25, V31, V34–V35, V37, V38, V40, V42) are reported as defects with severity; ≥2 of them or any data-integrity finding (e.g. a history row for a rejected/no-op change, state/history mismatch, cross-tenant leak, missing lock) escalates to round FAIL.
- Report: table V1..V42 with PASS/FAIL/SKIPPED (+reason), list of new test files under `tests/verify/`, list of baseline-red tests, and for each FAIL the minimal repro (test name, observed vs expected). Keep verifier tests in the repo for the tech lead to re-run: `pytest tests/verify -q`.
