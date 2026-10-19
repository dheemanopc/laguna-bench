# ORDER dev2-1 — work items: MCP write tools (WP2)

Feature: a mind-map node can be marked as a "work item" (kind story|epic|milestone; status
todo|in_progress|blocked|done|cancelled; optional assignee = a team member) with an append-only history.
dev1 is writing, AT THE SAME TIME, the migration (tables `work_items`, `work_item_history`) and the service module
`src/mem_mcp/mindmap/work_items.py`. You own the MCP tool layer: new files in `src/mem_mcp/mcp/tools/`, edits to
`src/mem_mcp/mcp/tool_descriptions.py`, `src/mem_mcp/main.py`, `src/mem_mcp/audit/logger.py`, and the test file
`tests/integration/test_mindmap_work_items_e2e.py`. DO NOT edit dev1's files (`alembic/**`, `mindmap/work_items.py`,
`tests/unit/test_work_items_service.py`). Code against the interface below verbatim. dev1 applies the migration to the
shared test DB within minutes; the service file may appear a bit later — write your code first, then poll (re-run
`pytest`) before declaring problems. If after your own work is finished the service is still missing/incompatible,
report precisely instead of editing it.

## Service interface (from `mem_mcp.mindmap.work_items`)
Functions (all `async`, keyword-only after `conn`, run inside your `tenant_tx`; return `WorkItem`):
`mark_work_item(conn, *, tenant_id, team_id, map_key, node_id, kind, assignee_id=None, reason=None, channel="mcp")`,
`set_work_item_status(conn, *, tenant_id, team_id, map_key, node_id, status, reason=None, expected_status=None, channel="mcp")`,
`set_work_item_kind(conn, *, tenant_id, team_id, map_key, node_id, kind, reason=None, channel="mcp")`,
`assign_work_item(conn, *, tenant_id, team_id, map_key, node_id, assignee_id: UUID | None, reason=None, channel="mcp")`.
Pass `tenant_id=ctx.tenant_id`, `team_id` from `_mindmap_common.resolve_team_id`, `channel="mcp"`.
`WorkItem` (frozen dataclass): memory_id, root_memory_id, map_key, map_state, team_id, kind, status, assignee_id, title,
created_by, created_at, updated_at, status_changed_at. Constants `WORK_KINDS`, `WORK_STATUSES`.
Exceptions (base `WorkItemError`): `WorkItemMapNotFoundError`, `WorkItemPermissionDeniedError(.permission: Permission, .team_id)`,
`NodeNotInMapError`, `NotAWorkItemError`, `InvalidKindError(.kind, .allowed)`, `InvalidStatusError(.status, .allowed)`,
`RootNodeNotAllowedError`, `AlreadyWorkItemError`, `MapNotLiveError`, `InvalidTransitionError(.current, .requested)`,
`ReasonRequiredError(.current, .requested)`, `StatusUnchangedError(.current)`, `StatusConflictError(.expected, .actual)`,
`KindUnchangedError(.kind)`, `AssigneeUnchangedError(.assignee_id)`, `InvalidAssigneeError(.assignee_id)`.
Check order inside the service: map found → caller has a role on the team → write permission → op rules.

## Tools (one module each, house style of `mindmap_resolve.py`; scope `memory.write`)
- `mindmap_work_mark` — `MindmapWorkMarkInput`: map_key (1..64), node_id UUID, kind `str` (NOT Literal — the service error must name allowed kinds), assignee_id UUID|None, reason str|None (max 2000), team_id UUID|None; `extra="forbid"`.
- `mindmap_work_set_status` — map_key, node_id, status `str`, reason?, expected_status `str|None`, team_id?.
- `mindmap_work_set_kind` — map_key, node_id, kind `str`, reason?, team_id?.
- `mindmap_work_assign` — map_key, node_id, assignee_id UUID|None (null = unassign; field required, no default, so omission is an error), reason?, team_id?.
Output model (shared, put it and the exception→JsonRpcError mapper in a new `_work_item_common.py`): `WorkItemOutput`: node_id, map_key, map_state, kind, status, assignee_id, title, created_by, created_at, updated_at, status_changed_at, request_id. Use user-facing word "assignee" (never "owner") in names/descriptions/messages.
Each tool: `async with tenant_tx(ctx.db_pool, ctx.tenant_id) as conn:` → resolve_team_id → service call → audit (below), map errors with `raise JsonRpcError(...) from e`.

## Error mapping (all `data` carry `errors: [{path, message}]` like existing tools plus `code`)
- WorkItemMapNotFoundError → `-32602`, message "map not found", `data={"errors":[{"path":"map_key"}]}` — EXACTLY what `mindmap_resolve` returns (opaque; no code key).
- WorkItemPermissionDeniedError → `-32603`, `data={"missing_permission": e.permission.value}`.
- NodeNotInMapError → `-32602` "node is not a member of this map", errors path node_id (same as mindmap_resolve).
- NotAWorkItemError → `-32602`, code `not_a_work_item`, path node_id.
- InvalidKindError / InvalidStatusError → `-32602`, code `invalid_work_item_kind` / `invalid_work_item_status`, message must list allowed values (e.g. "kind must be one of: story, epic, milestone"), path kind / status, plus `data["allowed"]` list.
- RootNodeNotAllowedError → `-32602`, code `root_node_not_allowed`, path node_id.
- AlreadyWorkItemError → `-32602`, code `already_work_item`, path node_id.
- MapNotLiveError → `-32602`, code `map_not_live`, message like the existing "map is archived; archived maps are no-reopen", path map_key.
- InvalidTransitionError → `-32602`, code `invalid_transition`, message "cannot change work item status from <current> to <requested>", `data["current_status"]`, `data["requested_status"]`, path status.
- ReasonRequiredError → `-32602`, code `reason_required`, message names the transition, path reason, plus current/requested in data.
- StatusUnchangedError → `-32602`, code `status_unchanged`, `data["current_status"]`.
- StatusConflictError → `-32602`, code `status_conflict`, message reports actual status, `data["current_status"]=actual`, `data["expected_status"]`, path expected_status.
- KindUnchangedError → code `kind_unchanged`; AssigneeUnchangedError → code `assignee_unchanged`; InvalidAssigneeError → code `invalid_assignee`, message "assignee must be a current owner, admin or member of the map's team", path assignee_id.
- Any other `WorkItemError` → `-32602` with code `work_item_error`. (Do not swallow non-WorkItemError exceptions.)

## Audit (CONVENTIONS "Audit & logging")
Add `"mindmap.work_item_changed"` to `AuditAction` in `audit/logger.py`. After a successful service call (same transaction) call `ctx.deps.audit.audit(conn, action=..., result="success", tenant_id=ctx.tenant_id, identity_id=ctx.identity_id, client_id=ctx.client_id, request_id=ctx.request_id, details={"node_id":..., "change": "created|status|kind|owner", "map_key":...})` when `ctx.deps` is not None — look at how `mindmap_close.py` / other tools do it and copy that. Details: ids and enum values only, never node content or reasons.

## Descriptions & registration
Add four entries to `TOOL_DESCRIPTIONS` in the house style (what it does, "Call when:", "Do not call for:", "Examples: … → …"); make clear: work-item status is independent of branch status (`mindmap_resolve`) and map close; there is no un-mark (use status `cancelled`); transitions table summary (todo→in_progress|cancelled; in_progress→blocked|done|todo|cancelled; blocked→in_progress|cancelled; done→in_progress; cancelled→todo; reasons required for →blocked, →cancelled, and leaving done/cancelled); `expected_status` guards against races; archived maps: cannot mark, can still change. Register the 4 classes in `main.py` grouped under the mindmap family. Check whether any existing test pins the tool list/count or description coverage (grep tests for `TOOL_DESCRIPTIONS`, tool counts) and satisfy such invariants without modifying tests unless they only enumerate (if a pinned list must change, tell me in the report).

## Tests: `tests/integration/test_mindmap_work_items_e2e.py`
Follow `tests/integration/test_mindmap_e2e.py` fixtures (UUID-suffixed data). Through the TOOLS (not the service) cover: mark happy path (story/epic/milestone, with and without assignee) then verify DB row state todo; bad kind error names allowed kinds, no row; root node; node from another map; duplicate mark unchanged; archived map mark rejected but status/kind/assign still work after close; each allowed transition; disallowed transitions error data (current/requested) and history count unchanged; reason required with None and blank; same status; expected_status mismatch reports actual; branch status in memory_map_membership unchanged after work-item status change and work-item status unchanged after `mindmap_resolve`; viewer (insert a viewer role assignment in `team_role_assignments`, see tests/unit/test_team_api.py / assignments helpers) gets `-32603` + missing_permission and no change; user not on team gets the exact same JsonRpcError (code, message, data) as a nonexistent map_key; invalid assignee (viewer/non-member); assign/reassign/unassign; one history row per success with channel 'mcp' and actor = tenant; existing `mindmap_get` output for a plain node unchanged. If the service isn't ready yet when you finish coding, wait/poll; do not stub it.

## Verify before reporting
`pytest tests/integration/test_mindmap_work_items_e2e.py -q`, `pytest -q` (no new failures vs ~/laguna-bench/runs/F1-1/orders/known_red_base.txt), `ruff check src tests`, `mypy`.
Report: files changed, commands+results, uncertainties.
