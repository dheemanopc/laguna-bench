# ACCEPTANCE — F1 round 1 (WP1 service + migration, WP2 MCP write tools)

Reviewer: Product Owner. Scope: only what this round claims to deliver. Evidence is from
reading `feature.diff` / the repo and the tests. I did not run the suite myself; I rely on the tech lead's
targeted run (97 passing) for pass/fail.

## Overall verdict: **ACCEPT WITH FIXES**

The core of the feature is right. A node can be marked as a story, epic or milestone. The ten-transition
workflow matches brief 4.2 exactly (`mindmap/work_items.py:36-47`). Every change writes one history row with
a full before/after snapshot, the actor and the channel. Archived maps allow changes to existing items but
no new ones. Errors are structured and name the allowed kinds and the current and requested status.

I accept this round as the base to build on, with the fixes in §3. Two business issues (§2, C1 and C2) must
be settled before the feature can be released. They don't block this round.

---

## 1. Acceptance criteria claimed this round

| AC | Verdict | Evidence / note |
|---|---|---|
| 1 Mark non-root node, live map, kind + todo + owner | **MET** | `work_items.py:448-591`; e2e `test_work_item_mark_happy_path_story`, `_with_assignee`, `_milestone_kind`. "Shows as a work item" is only in the tool response for now. Showing it in `mindmap_get` is AC32 (next round). |
| 2 Bad kind rejected, names allowed kinds | **MET** | `_work_item_common.py` InvalidKindError → "kind must be one of: story, epic, milestone" + `allowed`; e2e `test_work_item_mark_bad_kind_error`. |
| 3 Root node rejected | **MET** | `work_items.py:475`; e2e `test_work_item_mark_root_node_rejected`. |
| 4 Already a work item rejected, unchanged | **MET** | `work_items.py:486-494`, race handled at `:533`; `test_work_item_mark_duplicate_rejected`, `test_mark_race_condition_unique_violation`. |
| 5 Archived map: mark rejected | **MET** | `work_items.py:482`; e2e `test_work_item_archived_map_mark_rejected_status_change_works`. |
| 6 Node not in named map rejected | **MET** | `_check_node_membership`; `test_work_item_mark_node_from_another_map`, `test_wrong_map_key_rejected`. |
| 7 Marking changes nothing about the node; existing tools unchanged | **MET (by construction), thin test** | `memories` and `memory_map_membership` are untouched (side tables only). `test_work_item_get_for_plain_node_unchanged` checks only content. Turn, links and branch status of the marked node are not checked. Side effect: each change also appends a `work_item` row to `memory_map_events`, which now appears in the map's recent-events feed (`service.py:480`). That is acceptable and intended (AC32/36). |
| 8 Every allowed transition succeeds | **MET** | Service: `test_allowed_status_transitions` covers all 10 rows. Through the tool: 6 of 10 in `test_work_item_status_transitions`. |
| 9 Disallowed transition rejected, names current + requested, no history | **MET** | `InvalidTransitionError` mapping carries `current_status`/`requested_status`; `test_disallowed_status_transitions` covers the four examples from the brief. |
| 10 Reason required (none/blank) | **MET** | `_clean_reason` + `check_transition`; `test_reason_required_with_none`, `_with_whitespace`, e2e `test_work_item_reason_blank_rejected`. |
| 11 Same status rejected, no history | **MET** | `work_items.py:626`; `test_status_unchanged_error`, e2e `test_work_item_same_status_unchanged`. |
| 12 Expected-status mismatch reports actual | **MET** | `work_items.py:622`, `data.current_status`; `test_work_item_expected_status_mismatch`. |
| 13 Work status ⟂ branch status (both directions) | **PARTLY** | Work status → branch is tested (`test_work_item_branch_status_unchanged`). Branch resolve/drop → work status is true by construction, because resolve doesn't touch `work_items`, but no test covers it. |
| 14 Closing a map leaves status/kind/owner unchanged | **PARTLY** | Only implied: in the archived e2e test, todo→in_progress works after close. No test asserts that kind and assignee are unchanged after `mindmap_close`. |
| 15 Assign / reassign / unassign, visible straight away | **MET** | `assign_work_item`; e2e `test_work_item_assign_reassign_unassign`. Note C1: the assignee may be unable to see the item. |
| 16 Assign to viewer/vendor/non-member rejected | **MET** | `ASSIGNABLE_ROLES` (`work_items.py:31`); `test_assign_invalid_assignee` (vendor), `test_cross_tenant_assignee_rejected`. |
| 17 Change kind; same kind rejected, no history | **MET** | `set_work_item_kind`; e2e `test_work_item_kind_change`, `test_kind_unchanged_error`. |
| 18 Archived map: status, owner, kind still changeable | **PARTLY** | Status is tested through the tool, kind only at service level (`test_kind_on_archived_map_allowed`). Assign on an archived map is not tested anywhere. The code has no state check, so it is probably fine. |
| 19 Viewer can read; all writes rejected with permission error, nothing changes | **PARTLY** | Write denial is tested only for **mark** (`test_work_item_viewer_permission_denied`, `test_viewer_permission_denied`). Set-status, set-kind and assign use the same `_check_permission`, but no test covers them. The read half (list, read, history) has no tool yet. |
| 21 Tenant isolation | **MET (structural)** | RLS on both tables (`0046` policies) plus an explicit `tenant_id` in every query; `test_two_tenant_isolation`. |
| 25 One history entry per success with all fields | **MET (data level)** | Snapshot columns, actor, channel, reason, `clock_timestamp()` (`0046`, `_append_history`); `test_work_item_history_one_row_per_success` covers created, status and kind. No tool-level test counts history for an owner change. Users can't see history until `mindmap_work_history` exists. |
| 26 Rejected attempts add no history | **MET** | Every check runs before any write; the unique-violation path uses a savepoint; the tool's transaction rolls back on error. |
| 28 No way to edit/delete history | **PARTLY** | The grants are correct: `GRANT SELECT, INSERT` only, plus deny policies (`0046`). But `test_history_append_only` only checks that the policy names exist; it never tries an UPDATE or DELETE as `mem_app`. History can also disappear through node deletion (see C2). |
| 30 Removed assignee remains, by identity, in history and as owner | **PARTLY** | Design is right: `assignee_id` has no FK and there is no check on read. But `test_reassigned_member_remains_assignee` *downgrades to viewer* rather than removing the member. It then only asserts `AssigneeUnchangedError` and never reads the current owner or the history after removal. |

**Service-level only (claimed as groundwork, not yet user-facing):** 22–24, 27, 29. `list_work_items`
(filters, `map_state`, title, map_key, updated_at), `get_work_item_history` (oldest-first by id), and the tests
`test_last_history_matches_current_state` and `test_history_oldest_first` are good groundwork. I mark them
**NOT MET as user-facing criteria**: no tool or screen exposes them yet. Before WP3, the service also needs
"assigned to me" (the caller can pass their own id, but the tool must offer it) and must exclude deleted nodes
consistently. `get_work_item_history` doesn't filter on `deleted_at`, but `list_work_items` does.

**Not claimed but partly present:** AC20. A non-member gets the same "map not found" as for a missing map
(`_load_map`, mapping in `_work_item_common.py`). But `test_work_item_user_not_on_team_same_error` uses a
*random, non-existent* map key, so it doesn't prove this for a real map of another team. Please fix the test
when AC20 is claimed.

---

## 2. Where design or code contradicts the business intent

**C1 — "Team" work only works within one tenant. Must decide before release; doesn't block this round.**
In this codebase a tenant is a person (DESIGN §0). The work-item tables use the same tenant-only RLS as
`memory_maps`. In practice, only the tenant that owns the map can see or change its work items. A teammate
who is assigned an item can't see it, can't move it, and won't find it under "assigned to me". This defeats
brief 4.3 ("any write-capable team member may change any work item"), story 5 ("what's on my plate?") and
story 7 (the lead's team-wide view).

The limitation comes from the existing map tables, and the brief does say "exactly as visible as the map".
So this is not a regression by this round, and I am not rejecting for it.
**Owner decision:** v1 cannot be released without team-aware access. At minimum, team members with a role
must be able to read work items and their history on the team's maps, members must be able to change them,
and assignees must find their items. The tech lead should design this together with WP3 rather than after
it. If it needs map-level sharing first, tell me and I will re-plan the scope.

**C2 — Deleting a node silently removes a work item and, later, its history.**
`work_item_history.memory_id` is `REFERENCES memories(id) ON DELETE CASCADE` (`0046`). Nodes can be
soft-deleted by the existing delete tool and by the retention job (`jobs/retention_memories.py:88`). They are
then hard-deleted after 30 days (`retention_memories.py:118`), and that erases the work item's history. Even
before the purge, soft-deleted items drop out of listings and the embedding (`work_items.py:1266`).

This contradicts 4.4 ("append-only… no one can edit or delete them", AC29 "no gaps"). It also contradicts
§6, where un-marking is out of scope and `cancelled` is the way out. Deleting a work-item node is a backdoor
un-mark.
**Owner decision:** history must survive node deletion (no cascade from `memories` to the history).
Deleting a node that is a work item should be refused with a pointer to "cancel it instead", or at least it
must leave a history entry. Erasure on account deletion (`identity/lifecycle.py:299`) is a legal requirement
and is acceptable.

**C3 — Who counts as a writer (minor).** Writes are gated on `TEAM_WRITE_MEMORY`, which the design says
service-bot also holds. The brief's permission table names only owner, admin and member. Accept for now, but
history must show that it was a bot, and that is not visible today. Please confirm which roles hold the
permission and tell me.

**C4 — Error style (minor).** Permission denied is returned as `-32603`. `errors.py:8` documents that code
as "server errors" (server bug). It matches the team tools (`assign_role.py:51`), so AC31's "same style"
is arguably met. An agent may still read it as a crash rather than "you're not allowed". I'd prefer
`-32000` with a `code`, but I won't hold the round on it.

---

## 3. Fixes required (to complete this round's acceptance)

1. **Stale timestamps in responses.** `set_work_item_status` and `set_work_item_kind` return the
   *pre-update* `updated_at`/`status_changed_at` (`work_items.py:701-702`, `804-805`). So "since when is it in
   this status?" (4.4 Q1) is wrong in the tool's answer. Return the post-update row, the way
   `assign_work_item` already does.
2. **Tool description accuracy.** The `mindmap_work_mark` description lists reason-required transitions as
   "leaving done/cancelled, and for status→blocked". It leaves out →cancelled. The set_status text is correct;
   make them agree.
3. **Fix the error wording.** "map is archived; archived maps are no-reopen" is not user-facing English. Use,
   for example, "map is archived; new work items can't be created on an archived map (existing ones can still
   be updated)".
4. **Close the test gaps** for AC13 (reverse direction), AC14 (kind and assignee after close), AC18 (assign
   on an archived map), AC19 (viewer denied on set_status, set_kind and assign), AC28 (a real UPDATE/DELETE
   attempt as `mem_app` fails) and AC30 (actually remove the member, then read the current assignee and the
   history).
5. **Remove the no-op migration `0047`** before release.
6. **Run the full suite and mypy on the final code.** The last full run was before dev1's final change, and
   mypy was not run by the tech lead. Explain the 10 `test_web_teams_api` failures, or show they also fail on
   the baseline.
7. **Agent usability check (confirm, don't necessarily build).** The descriptions show "Assign to Alice" →
   `assignee_id="<alice-uuid>"`. Confirm that an ordinary member's agent can find a teammate's id with the
   existing tools (`list_my_teams` or another). If it can't, assignment through the agent isn't usable and
   that becomes a WP3 item.

## 4. Answers to the brief's open questions (owner decisions)

1. **Archived maps:** confirmed. Work on existing items continues after the map is archived; no new items.
   The implementation matches.
2. **Agent changing status on its own:** the agent changes status only when the person asks for it or
   confirms it. It doesn't infer "done" from the conversation. The tools stay permissive and the channel is
   recorded. WP6 (mindmap-driver skill) must say this, and the tool descriptions should say it too
   ("Call when: user says…" already leans that way).
3. **"Assignee":** confirmed as the user-facing word everywhere (tool params, errors and web UI already use
   it). The internal `change_type = 'owner'` is fine as long as no screen shows the raw value.

## 5. Still missing for the whole feature

- **WP3, agent reads:** `mindmap_work_list` (per map and team-wide, filters including "unassigned", "assigned
  to me" and map state, AC22–24), `mindmap_work_history` (AC19 read half, 25 visibility, 27, 29) and
  work-item fields in `mindmap_get` (AC32). AC31 can only be met after this.
- **Team-aware access (C1)**, so that teammates and assignees can see and change items.
- **History survives node deletion (C2).**
- **WP4, read-only web endpoints**, and **WP5, web UI:** a badge on map nodes, a team-wide list with
  filters and a history panel (AC33–36).
- **WP6:** mindmap-driver skill guidance (open question 2) and docs.
- AC20 with a real cross-team map test.
