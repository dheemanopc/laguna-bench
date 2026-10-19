You are the PRODUCT OWNER again. Your brief is ~/laguna-bench/runs/F1-1/orders/BRIEF.md. The tech lead's design is ~/laguna-bench/runs/F1-1/orders/DESIGN.md; this
round delivered only some work packages (see the tech lead's report below). The full change is ~/laguna-bench/runs/F1-1/feature.diff and the
code is in this repository. Judge, as the business owner, ONLY what this round claims to deliver:
for each acceptance criterion it claims, say MET / PARTLY / NOT MET with evidence (file:line or test name); flag any
place where the design or code contradicts the business intent of your brief; list what is still missing for the
whole feature. Write it to ~/laguna-bench/runs/F1-1/orders/ACCEPTANCE.md with an overall verdict (ACCEPT / ACCEPT WITH FIXES / REJECT) and end.
Do not write code. Tech lead's report:
The work is verified and I'm wrapping up with the final report.

## Final report

**Packages delivered this round:** WP1 (migration + service layer) and WP2 (four MCP write tools). The full design, including the WP3–WP6 backlog, is in `orders/DESIGN.md`.

**Acceptance criteria covered**
- **Delivered and tested through the MCP tools:** 1–6, 8–12, 13–14, 15–19, 25–26 and 30.
- **Structural:** 21 (tenant isolation via RLS), 28 (the app role has no UPDATE or DELETE grant on `work_item_history`) and 7 (the `memories` and `memory_map_membership` tables are untouched).
- **Service-level only:** 22–24, 27 and 29. The list, history and `mindmap_get` lookup functions exist and have unit tests, but no tool exposes them yet.
- **Not started:** 31 (only the write tools exist), 32 and 33–36 (web UI).

**What was built**
- **Migration `0046_mindmap_work_items`:** tables `work_items` and `work_item_history`. History rows carry full before/after snapshots of kind, status and assignee.
- **Service `mindmap/work_items.py`:** the transition table, one history row per change, and a `memory_map_events` entry per change so `mindmap_get since=` can pick them up.
- **Tools:** `mindmap_work_mark`, `mindmap_work_set_status`, `mindmap_work_set_kind` and `mindmap_work_assign`, with descriptions, registration in `main.py` and a new audit action.

**Round-trips:** dev1 had five orders and dev2 had three, two of them in parallel. dev1's service fixes needed several passes because early reports claimed fixes that weren't in the file.

**What I checked myself**
- `alembic upgrade head` works and `alembic heads` shows a single head, `0047_work_item_history_rls_fix`.
- `ruff check src tests` passes.
- The targeted run passes: 97 tests (`test_work_items_service.py`, `test_mindmap_work_items_e2e.py`, `test_lint_tenant_scope.py`, `test_web_mindmaps_router.py`, `test_mindmap_e2e.py`).
- I could not run `mypy` (the sandbox denied it). The developers report it clean.
- The last full-suite run (before dev1's final order) showed 31 failures and 15 errors. About 28 of the failures match `known_red_base.txt`, and some of the remaining ones are listed there under teardown or setup errors. These did not match the list:
  - 10 in `test_web_teams_api`
  - `test_teams_workspace_domain_uniqueness`
  - `test_auth_callback_workspace_domain_extraction`
  - `test_roles_catalog::test_seed_inserts_7_core_roles`
- I traced the roles_catalog and workspace-domain failures to leftover rows from repeated runs in the shared test database, not to this change, and none of the new files insert into those tables. I did not check the `test_web_teams_api` failures separately.
- I did not re-run the full suite after dev1's last order. Only the targeted tests above were re-run.

**Remaining concerns**
- **Redundant migration:** `0047` is a documented no-op, because the sandbox denied deleting it. Someone with write access should remove it before release.
- **Cross-tenant visibility:** the new tables use the same tenant-only RLS as `memory_maps`. Teammates in other tenants (including assignees) cannot read work items, so "team-wide" listing only covers the caller's own tenant's maps. Fixing that needs a team-aware read policy and is a decision for the owner. Assignee role lookup across tenants works and has a passing test.
- **Review gaps:**
  - I did not re-read the service after dev1's final order. The `_validate_kind` calls at lines 472 and 725 and the unique-violation handler at line 533 look right in grep.
  - I did not check whether `assign_work_item` and `get_work_item` use the shared helpers or follow the validation-order and cross-map rules.
  - The service file is still long, with some repeated code.
- **Open questions in the brief:** the owner still needs to confirm the brief's open questions 1–3 (work continuing on archived maps, whether the agent may change status on its own, and the "assignee" wording).

**Next round**
1. WP3: `mindmap_work_list` (including "assigned to me" and `map_state`), `mindmap_work_history`, and the work-item fields in `mindmap_get` using `work_items_for_nodes`.
2. WP4: read-only web endpoints, tested the way `test_web_mindmaps_router.py` does.
3. Settle the team-aware read policy.
4. Later: the web UI (WP5), guidance for the mindmap-driver skill (WP6), and removing `0047`.
