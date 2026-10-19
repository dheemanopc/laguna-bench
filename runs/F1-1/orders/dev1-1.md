# ORDER dev1-1 — work items: migration + service layer (WP1)

Feature: a mind-map node can be marked as a "work item" (kind story|epic|milestone; status
todo|in_progress|blocked|done|cancelled; optional assignee = a team member) with an append-only
history. You own: the migration, `src/mem_mcp/mindmap/work_items.py`, and its tests. dev2 works at the same
time on the MCP tools in `src/mem_mcp/mcp/**`, `src/mem_mcp/main.py`, `src/mem_mcp/audit/logger.py` and
`tests/integration/test_mindmap_work_items_e2e.py`. DO NOT touch those files. dev2 codes against the interface below
verbatim — do not rename anything.

FIRST (within minutes): write the migration and run `alembic upgrade head` so dev2 can use the tables; then do the service.

## Migration `alembic/versions/0046_2026_10_16_mindmap_work_items.py`
revision `0046_mindmap_work_items`, down_revision = revision id of 0045 (read it). Follow 0038/0044 style (docstring with the why, downgrade).
Peer RLS pattern (`tenant_id = safe_current_tenant_id()`), explicit GRANTs to mem_app.

`work_items`: `memory_id UUID PK REFERENCES memories(id) ON DELETE CASCADE`; `root_memory_id UUID NOT NULL REFERENCES memory_maps(root_memory_id) ON DELETE CASCADE`; `tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE`; `team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE`; `kind TEXT NOT NULL` CHECK in (story,epic,milestone); `status TEXT NOT NULL DEFAULT 'todo'` CHECK in (todo,in_progress,blocked,done,cancelled); `assignee_id UUID NULL` (a tenant id; deliberately NO FK so a removed member stays visible as assignee — comment why); `created_by UUID NOT NULL`; `created_at`, `updated_at`, `status_changed_at` timestamptz NOT NULL DEFAULT now(). Indexes: (tenant_id, team_id, status); (root_memory_id); (assignee_id) WHERE assignee_id IS NOT NULL. RLS select/insert/update policies; GRANT SELECT, INSERT, UPDATE (no DELETE).

`work_item_history` (append-only): `id BIGSERIAL PK`; `memory_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE`; `root_memory_id UUID NOT NULL`; `tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE`; `team_id UUID NOT NULL`; `change_type TEXT NOT NULL` CHECK in (created,status,owner,kind); snapshot columns `kind_before TEXT NULL, kind_after TEXT NOT NULL, status_before TEXT NULL, status_after TEXT NOT NULL, assignee_before UUID NULL, assignee_after UUID NULL` (every row stores the full state before and after the change; for 'created' all *_before are NULL; so the last row's *_after always equals the item's current state); `actor_id UUID NOT NULL`; `channel TEXT NOT NULL` CHECK in (mcp,web); `reason TEXT NULL`; `created_at timestamptz NOT NULL DEFAULT clock_timestamp()`. Indexes (memory_id, id); (tenant_id, actor_id, created_at). RLS select+insert policies ONLY; `GRANT SELECT, INSERT` only plus `GRANT USAGE, SELECT ON SEQUENCE work_item_history_id_seq`. No update/delete policy or grant (append-only, admins included) — put that reasoning in the docstring.

## Service `src/mem_mcp/mindmap/work_items.py`
Module docstring explains purpose/why. Takes `asyncpg.Connection` from `tenant_tx`; never imports FastAPI or JsonRpcError. All SQL has explicit `tenant_id = $n` plus RLS (run `tools/lint_tenant_scope.py` via its unit test).

Constants: `WORK_KINDS = ("story","epic","milestone")`, `WORK_STATUSES = ("todo","in_progress","blocked","done","cancelled")`, `ASSIGNABLE_ROLES = frozenset({"owner","admin","member"})`, `Channel = Literal["mcp","web"]`, `TRANSITIONS: dict[tuple[str,str], bool]` (value = reason required) exactly:
todo→in_progress F; todo→cancelled T; in_progress→blocked T; in_progress→done F; in_progress→todo F; in_progress→cancelled T; blocked→in_progress F; blocked→cancelled T; done→in_progress T; cancelled→todo T. Nothing else.
Pure `check_transition(current: str, requested: str, reason: str | None) -> None` raising the errors below.

Exceptions (all subclass `WorkItemError(Exception)`, plain attributes, sensible `str()`):
- `WorkItemMapNotFoundError` (map_key unknown OR caller has no role on the map's team — must be indistinguishable)
- `WorkItemPermissionDeniedError(permission: Permission, team_id: UUID)` (caller has a role but lacks TEAM_WRITE_MEMORY)
- `NodeNotInMapError` (node not a member of that map / deleted)
- `NotAWorkItemError` (node in map but not marked)
- `InvalidKindError(kind, allowed)`, `InvalidStatusError(status, allowed)`
- `RootNodeNotAllowedError`, `AlreadyWorkItemError`, `MapNotLiveError` (mark on archived map only)
- `InvalidTransitionError(current, requested)`, `ReasonRequiredError(current, requested)`, `StatusUnchangedError(current)`, `StatusConflictError(expected, actual)`
- `KindUnchangedError(kind)`, `AssigneeUnchangedError(assignee_id)`, `InvalidAssigneeError(assignee_id)`

Dataclasses (frozen): `WorkItem(memory_id, root_memory_id, map_key, map_state, team_id, kind, status, assignee_id, title, created_by, created_at, updated_at, status_changed_at)` — `title` = first line of node content, max 120 chars (…); `WorkItemHistoryEntry(id, memory_id, change_type, kind_before, kind_after, status_before, status_after, assignee_before, assignee_after, actor_id, channel, reason, created_at)`.

Async functions (keyword-only after `conn`; `tenant_id` = caller, also the actor; `team_id` already resolved by the tool):
- `mark_work_item(conn, *, tenant_id, team_id, map_key, node_id, kind, assignee_id=None, reason=None, channel="mcp") -> WorkItem`
- `set_work_item_status(conn, *, tenant_id, team_id, map_key, node_id, status, reason=None, expected_status=None, channel="mcp") -> WorkItem`
- `set_work_item_kind(conn, *, tenant_id, team_id, map_key, node_id, kind, reason=None, channel="mcp") -> WorkItem`
- `assign_work_item(conn, *, tenant_id, team_id, map_key, node_id, assignee_id: UUID | None, reason=None, channel="mcp") -> WorkItem`
- `get_work_item(conn, *, tenant_id, team_id, map_key, node_id) -> WorkItem` (read; any role; NotAWorkItemError if absent)
- `list_work_items(conn, *, tenant_id, team_id, map_key=None, status=None, kind=None, assignee_id=None, unassigned=False, map_state=None, limit=100) -> list[WorkItem]` (map_key None = whole team; caller must have a role on team, else WorkItemMapNotFoundError; ordered updated_at DESC, memory_id; excludes deleted nodes; includes live+archived unless map_state given; validate status/kind filters)
- `get_work_item_history(conn, *, tenant_id, team_id, map_key, node_id) -> list[WorkItemHistoryEntry]` (oldest-first by id)
- `work_items_for_nodes(conn, *, tenant_id, node_ids: list[UUID]) -> dict[UUID, WorkItem]`-like light lookup returning `dict[UUID, tuple[str,str,UUID|None]]` (kind, status, assignee_id) for mindmap_get embedding (WP3, implement now).

Rules (check order for every write): resolve map via `service.resolve_map_root` + `get_map_row` (missing → MapNotFound); `auth.rbac.get_team_role(conn, tenant_id, team_id)` None → MapNotFound; role lacks `Permission.TEAM_WRITE_MEMORY` (use `ROLE_PERMISSIONS`) → PermissionDenied; then op-specific:
- mark: validate kind (message names allowed kinds) → node must be in `memory_map_membership` of this root and memory not deleted (else NodeNotInMap; node_id == root id → RootNodeNotAllowed — decide root check BEFORE membership check since root may not be in membership) → map state live (else MapNotLive) → not already marked (AlreadyWorkItem; also catch UniqueViolation) → assignee validation → insert + history 'created' (status 'todo').
- status: `SELECT … FOR UPDATE` the work_items row (tenant-scoped); validate status value; if expected_status given and != actual → StatusConflict(actual); same → StatusUnchanged; `check_transition` (blank/whitespace reason counts as none; store stripped reason or NULL); update status, status_changed_at=now(), updated_at=now(); history 'status'. Allowed on archived maps.
- kind: validate; same → KindUnchanged; history 'kind'. Allowed on archived maps.
- assign: assignee None = unassign; same as current → AssigneeUnchanged; else assignee must have an ACTIVE role (via `get_team_role(conn, assignee_id, team_id)` — note RLS may hide other tenants' assignment rows under tenant_tx; if so do this lookup through a SECURITY DEFINER helper in the migration or an explicit-filtered query that works under RLS, and prove it with a test using two tenants) in `ASSIGNABLE_ROLES`, else InvalidAssignee. History 'owner'. Allowed on archived maps.
- Each successful write: exactly ONE history row (no row on any rejection — validate everything before any INSERT/UPDATE; failures must leave no partial writes), plus `service.log_event(... event="work_item", actor="model" if channel=="mcp" else "owner", memory_id=node_id, payload={"change": change_type, "from": ..., "to": ...})`. Do NOT touch memory_map_membership.status/turn, memories, or anything on map close.
- reason max 2000 chars → truncate-reject? Reject longer with `ValueError`? Use: tools validate length; service just strips.

## Tests (you own `tests/unit/test_work_items_service.py`, DB-backed, UUID-suffixed data; build tenants/teams/maps by directly inserting rows or via existing service helpers — see tests/integration/test_mindmap_e2e.py for fixtures)
Cover: every allowed transition succeeds; a sample of disallowed (blocked→done, todo→done, cancelled→in_progress, done→todo) raises InvalidTransition with current/requested and writes no history; reason-required cases with None and "  "; same status; expected_status conflict reports actual; mark validations (bad kind, root, non-member node, duplicate leaves existing unchanged, archived map); kind/assign on archived map allowed; viewer → PermissionDenied and nothing changed; non-member team → MapNotFound identical; two-tenant isolation; assignee rules (viewer/vendor/non-member rejected, owner unchanged on rejection; unassign; removed member remains assignee); one history row per change, oldest-first, last row's *_after matches current state; branch status in memory_map_membership unchanged after work-item status change; list filters (status/kind/assignee/unassigned/map_state, team-wide); history append-only (UPDATE/DELETE on work_item_history as mem_app role fails if the test infra can run as that role — otherwise assert grants via information_schema/has_table_privilege).

## Verify before reporting
`alembic upgrade head`, `pytest tests/unit/test_work_items_service.py tests/unit/test_lint_tenant_scope.py -q`, `pytest -q` (compare against ~/laguna-bench/runs/F1-1/orders/known_red_base.txt — no new failures), `ruff check src tests`, `mypy`.
Report: files changed, commands+results, uncertainties (esp. how the acting tenant's team role is found for maps created in a personal team).
