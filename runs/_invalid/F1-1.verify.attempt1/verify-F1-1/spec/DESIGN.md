# DESIGN — F1: Mind-map nodes as trackable work items

## 0. Readings / decisions on ambiguity
- "Person" = the authenticated tenant (`ctx.tenant_id`; in this codebase a tenant IS a user, and `team_role_assignments.member_id` for kind 'user' is a tenant id). Assignee = a tenant id.
- Work item = side table row keyed by the node's `memory_id` (additive; `memories` and `memory_map_membership` untouched → AC7).
- Reads/writes need a role on the map's team (`auth.rbac.get_team_role`). No role → behave as "map not found" (opaque). Write = `Permission.TEAM_WRITE_MEMORY` (owner/admin/member/service-bot hold it; viewer/vendor/customer don't → permission error). Assignee must hold role in {owner, admin, member} (explicit set; brief says nothing about service-bot → not assignable).
- Tenant RLS stays the peer pattern (tenant_id = safe_current_tenant_id()), same as memory_maps: cross-tenant team sharing of maps is a pre-existing limitation of the map tables; work items are exactly as visible as their map. (Concern for later round.)
- Several changes in one call are NOT supported: each tool call = exactly one change = exactly one history row (AC25).
- Channel: `mcp` | `web`. MCP tools always write `mcp`. Web UI editing is out of scope for v1.
- Work-item changes append a `memory_map_events` row (event `work_item`, actor `model` for mcp / `owner` for web) so `mindmap_get since=` deltas surface the node (AC32/36). Branch status untouched (AC13). Map close untouched (AC14).
- Reason: optional text, max 2000 chars, blank treated as absent; required per transition table.
- Assignee on archived map: status/kind/assign allowed; creating is not (AC5, AC18).
- Assignee later removed from team: stays (no FK, no check on read) (AC30). Assigning requires a *current* write-capable role at assign time only.

## 1. Data model (migration 0046, WP1)
`work_items` (one row per work-item node):
- `memory_id UUID PK REFERENCES memories(id) ON DELETE CASCADE`
- `root_memory_id UUID NOT NULL REFERENCES memory_maps(root_memory_id) ON DELETE CASCADE`
- `tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE`
- `team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE` (denormalised from map for team-wide listing)
- `kind TEXT NOT NULL CHECK (kind IN ('story','epic','milestone'))`
- `status TEXT NOT NULL DEFAULT 'todo' CHECK (status IN ('todo','in_progress','blocked','done','cancelled'))`
- `assignee_id UUID NULL` (tenant id; deliberately NO FK so history/current owner survive team/tenant churn)
- `created_by UUID NOT NULL`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at`, `status_changed_at` (all timestamptz default now())
- indexes: (tenant_id, team_id, status), (root_memory_id), (assignee_id) WHERE assignee_id IS NOT NULL
`work_item_history` (append-only):
- `id BIGSERIAL PK`, `memory_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE`, `root_memory_id`, `tenant_id`, `team_id`
- `change_type TEXT NOT NULL CHECK IN ('created','status','owner','kind')`
- `from_value TEXT NULL`, `to_value TEXT NULL` (kind/status text, assignee uuid as text; created: from NULL, to = JSON-free summary `kind` — see below)
- `actor_id UUID NOT NULL`, `channel TEXT NOT NULL CHECK IN ('mcp','web')`, `reason TEXT NULL`, `created_at timestamptz NOT NULL DEFAULT clock_timestamp()`
- index (memory_id, id); index (tenant_id, actor_id, created_at)
- 'created' row: `to_value` = kind; and the creation also writes initial status/assignee in two extra columns `to_status TEXT NULL`, `to_assignee UUID NULL`? -> NO: keep simple: creation writes ONE row (change_type 'created', to_value = kind) and additional columns `initial_status` is unnecessary because initial status is always `todo`; initial assignee, if given, is stored in column `assignee_after UUID NULL` … 
  FINAL: history carries explicit before/after snapshot columns so the last row's "after" always equals current state (AC27/29): `kind_before, kind_after, status_before, status_after, assignee_before, assignee_after` (nullable, kind/status text, assignee UUID) PLUS `change_type`. Every row fills all `*_after` columns with the full post-change state (snapshot) and `*_before` with the pre-change state (NULL for created). from_value/to_value columns are NOT used.
- RLS: ENABLE; SELECT+INSERT policies only; `GRANT SELECT, INSERT` only (no UPDATE/DELETE grant → append-only for the app role, admins included). `work_items`: SELECT/INSERT/UPDATE policies, GRANT SELECT, INSERT, UPDATE (no DELETE).

## 2. Service rules (`mem_mcp/mindmap/work_items.py`, WP1)
Transition table exactly as brief 4.2 (reason-required flags). Pure helper `check_transition(current, requested, reason)`. Check order for status change: validate status value → expected_status mismatch (actual reported) → same-status → not-in-table → reason required.
Operation order (all): resolve map (not found → opaque) → team role (none → opaque not found) → write permission (denied) → map-state rule (mark only) → node rules.
Mark rules: kind valid (error lists allowed kinds); node in map (else NotInMap); node is not root; not already a work item; map live; assignee valid; insert work_items row + 'created' history + map event, in the caller's tx. Status change takes `SELECT … FOR UPDATE` on the work_items row.
Errors are service-owned exception types (no JsonRpcError in service); tools map them.

## 3. MCP tools (WP2 write, WP3 read, scope noted)
- `mindmap_work_mark` (memory.write): map_key, node_id, kind, assignee_id?, reason?, team_id?
- `mindmap_work_set_status` (write): map_key, node_id, status, reason?, expected_status?, team_id?
- `mindmap_work_set_kind` (write): map_key, node_id, kind, reason?, team_id?
- `mindmap_work_assign` (write): map_key, node_id, assignee_id (null = unassign), reason?, team_id?
- `mindmap_work_list` (read): map_key? (omit = team-wide), status?, kind?, assignee_id?, unassigned?, assigned_to_me?, map_state? (live|archived), limit
- `mindmap_work_history` (read): map_key, node_id → entries oldest-first
- `mindmap_get` (read, existing): each node gains optional `work_item` {kind,status,assignee_id}. Existing output unchanged for non-work nodes.
Error mapping: see order dev2-1. Opaque not-found = identical to existing `-32602 "map not found"`.

## 4. Web UI (design only, not scheduled)
Read-only: `/api/web/mindmaps/{map_key}` nodes gain `work_item`; `GET /api/web/work-items` (filters as AC23); `GET /api/web/mindmaps/{map_key}/nodes/{id}/work-history`. SPA: badge on work nodes (kind icon, status chip, assignee), team list page, history side panel. Label "Assignee" everywhere.

## 5. Work packages
- WP1 (R1, dev1): migration 0046 + `mindmap/work_items.py` service incl. list/history reads + unit tests.
- WP2 (R1, dev2): four write tools + shared helper + descriptions + registration + AuditAction + e2e tests.
- WP3 (R2, dev2-ish): `mindmap_work_list`, `mindmap_work_history`, `mindmap_get` embedding (depends WP1).
- WP4 (R2): web read-only endpoints (+tests with fake pool pattern of test_web_mindmaps_router).
- WP5 (R3): SPA UI (not buildable here). WP6: skill guidance for mindmap-driver; docs.
Round 1 delivers: AC1–6, 8–12, 13–14 (by construction), 15–19, 25–26, 28 (no tool/grant), 21 (RLS), 30; service-level data for 22–24, 27, 29 (tools in R2).
