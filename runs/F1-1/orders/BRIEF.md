# BRIEF — F1: Mind-map nodes as trackable work items

Owner: Product. Audience: the engineers who will design and build this.
Status: ready for design. This brief says *what* and *why*. It does not say *how*.

---

## 1. Background (what exists today)

Memsys mind maps are where a person and their AI agent reason toward a decision. A
map is a root question plus member nodes (positions, challenges, notes, questions,
answers). Nodes are linked by typed edges. Each branch has a **branch status**
(open / resolved / dropped) and a **turn** (owner / model) that says whose move it
is. A map is **live** until it is closed. Closing graduates confirmed decisions into
long-term knowledge and **archives** the map. An archived map can't be reopened, but
people can still read it. Maps belong to a team. The agent works on maps through
`mindmap_*` MCP tools. People browse maps in the web UI under `/mindmaps`.

So the map records *thinking*. Nothing in it records *doing*. When the thinking
produces something to build or deliver ("ship the Redis hot path", "migrate tenants
by Q4"), that commitment leaves Memsys: it goes into a separate tracker or stays in
someone's head. The link back to the reasoning that justified it is lost.

## 2. Problem and who it is for

**Problem.** Teams can't turn the result of a mind-map discussion into tracked work
without leaving Memsys. They also can't later answer "who committed to this, what
state is it in, and how did it get there?" next to the reasoning behind it.

**For whom.**
- **Team members working with an agent** (primary). They want the agent to mark a
  node as a piece of work during or after a thinking session. Later they want to
  ask the agent "what's open, what's mine, what's blocked?"
- **The agent (model)** acting for a team member. It needs a reliable,
  rule-enforcing way to create work items and move them, so it can't invent states
  or skip steps.
- **Team leads / admins** using the web UI. They want to see the work that came out
  of the team's maps, who owns each item, and an honest history of changes, without
  going through the agent.

## 3. User stories

1. As a team member, I want to mark a mind-map node as a **story**, **epic** or
   **milestone**, so that a commitment from our thinking becomes trackable without
   copying it elsewhere.
2. As a team member, I want to give a work item an **owner** from my team, or leave
   it unassigned, so that it's clear who is responsible.
3. As a team member (or my agent), I want to move a work item through its
   **status** (e.g. start it, block it, finish it), so that its state is always
   current.
4. As a team member, I want illegal moves rejected with a clear reason (e.g. a
   cancelled item can't be marked done), so that the status means something.
5. As a team member, I want to list work items in a map, and across my team, by
   status, kind and owner, including "assigned to me". That way I can answer
   "what's on my plate?" without opening every map.
6. As anyone with read access, I want to see a work item's **full history** (every
   status change, owner change and kind change, with who, when, from what to what,
   and why) so that I can see how it got to where it is.
7. As a team lead, I want work items to show up in the **web UI**: marked on the
   map, in a team-wide list, and with a history view, so that I can follow progress
   without going through an agent.
8. As a team member, I want a work item to stay connected to its node and map, so
   that anyone looking at the work can follow it back to the reasoning that
   produced it.
9. As a viewer or external collaborator, I can see work items and their history in
   teams I can read, but I can't change them.

## 4. Business rules

### 4.1 What a work item is
- A work item is **an existing mind-map node that has been marked as work**. It is
  not a new, separate thing. Its title and description are the node's content. Its
  link to the reasoning is the map it belongs to.
- Marking is **opt-in, one node at a time**. Most nodes stay plain thinking nodes.
  Existing maps and nodes are unchanged by this feature (additive, non-breaking,
  in line with the mind-map founding constraints).
- A node is a work item at most once: one kind, one status and one owner at a time.
- **The map's root node can't be a work item.** The root is the question being
  explored, not a piece of work.
- A work item has:
  - **Kind**: one of `story`, `epic` or `milestone`. Kind can be changed later
    (e.g. a story turns out to be an epic), and the change is recorded in the
    history.
    - *story*: one deliverable piece of work.
    - *epic*: a larger body of work, usually made of several stories.
    - *milestone*: a checkpoint or target that the team reaches.
  - **Status**: see 4.2. A new work item starts in `todo`.
  - **Owner (assignee)**: one person on the map's team, or nobody (unassigned).
    *Terminology warning:* the map vocabulary already uses "owner" to mean "the
    human side of the conversation" (as in turn = owner/model). The work-item owner
    is a specific named team member. User-facing text must keep the two apart; we
    suggest calling it the "assignee" wherever the two could be confused.
- **Work-item status is separate from branch status and from map state.**
  - Resolving or dropping a branch does **not** change the status of a work item on
    that branch, and changing a work item's status doesn't resolve its branch. One
    is "is the thinking settled?", the other is "is the work done?".
  - Closing/archiving a map does **not** change its work items' statuses. The work
    usually outlives the thinking.
- Kinds have no hierarchy or containment in v1. Nothing requires stories to belong
  to an epic. People can still express a relationship with the existing map links,
  but the system doesn't interpret or enforce it.

### 4.2 Statuses and transitions
All three kinds use the same five statuses:

| Status | Meaning |
|---|---|
| `todo` | Agreed as work; not started. (Initial status.) |
| `in_progress` | Someone is actively working on it. |
| `blocked` | Started but can't proceed; the reason is recorded. |
| `done` | Delivered / reached. |
| `cancelled` | Won't be done; the reason is recorded. |

Allowed transitions (anything not listed is rejected):

| From → To | Reason required? | Notes |
|---|---|---|
| `todo` → `in_progress` | no | start |
| `todo` → `cancelled` | **yes** | decided not to do it |
| `in_progress` → `blocked` | **yes** | what it is blocked on |
| `in_progress` → `done` | no | finish |
| `in_progress` → `todo` | no | put back / stop work |
| `in_progress` → `cancelled` | **yes** | abandoned mid-way |
| `blocked` → `in_progress` | no | unblocked |
| `blocked` → `cancelled` | **yes** | abandoned while blocked |
| `done` → `in_progress` | **yes** | reopen: it wasn't really done |
| `cancelled` → `todo` | **yes** | revive a cancelled item |

- `done` and `cancelled` are *closed* statuses. Everything else is *open*. Leaving a
  closed status (reopen/revive) is allowed, but always needs a reason.
- `blocked` → `done` is **not** allowed. An item must be unblocked (back to
  `in_progress`) before it can be finished.
- A "change" to the current status (e.g. `todo` → `todo`) is rejected and is **not**
  recorded in the history.
- The caller may say which status they believe the item is currently in. If that
  doesn't match the actual current status, the change is rejected. This stops two
  people (or a person and an agent) from overwriting each other's moves without
  knowing it.

### 4.3 Who may change what
Permissions follow the existing team roles on the **map's team**:

| Action | team owner / admin / member | viewer / vendor (read-only roles) | not on the team |
|---|---|---|---|
| See work items and their history | yes | yes | no (behaves as if it doesn't exist) |
| Mark a node as a work item | yes | no | no |
| Change kind | yes | no | no |
| Change status | yes | no | no |
| Assign / reassign / unassign owner | yes | no | no |

- The **assignee must be a current member of the map's team** in a role that can
  write (owner, admin or member). Assigning to a viewer, a vendor or a non-member is
  rejected.
- Any write-capable team member may change any work item, not only their own. (v1
  trusts the team. "Only the assignee may complete it" is out of scope.)
- A person removed from the team stays as assignee on their items, so the history
  stays truthful. The items show up in listings as owned by someone who is no
  longer a member, so they can be reassigned.
- **Archived maps:** existing work items on an archived map **can still have their
  status, owner and kind changed** (the work goes on after the thinking closes), but
  **new** work items can't be created on an archived map.
- An agent acting on a person's token acts *as that person* and has the same
  permissions. The history must still show whether the change came through the
  agent (MCP) or directly from a person (web UI).
- Work items never cross team or tenant boundaries. They are exactly as visible as
  the map they live on.

### 4.4 Audit trail
Every change to a work item adds one entry to its history: being created as a work
item, every status change, every owner change and every kind change. History
entries are **append-only**. No one can edit or delete them, and that includes
team admins. Each entry records:

- **what** changed (status / owner / kind / created) and the **before → after**
  values;
- **who** made the change (the authenticated person);
- **through what** (agent via MCP tools, or a person via the web UI);
- **when**;
- **why**: the reason text, which is required for the transitions in 4.2 marked
  "yes" and optional for the rest.

The history must let someone answer, without guessing:
1. What is the item's current status, kind and owner, and since when?
2. Who marked this node as work, and when?
3. Who moved it to `done` (or `cancelled`), when, and through which channel?
4. Who owned it at a given past date?
5. Why is it blocked / why was it cancelled / why was it reopened?
6. How long did it spend in each status?
7. What did a given person change across a map or team in a given period?
8. Was a given change made by the agent or directly by a person?

## 5. Acceptance criteria

Unless stated otherwise, "a member" means an authenticated user with the
owner, admin or member role on the map's team, and "a viewer" means a user with the
viewer or vendor role on that team.

**Marking nodes as work**
1. A member can mark a non-root node of a live map as a work item of kind `story`,
   `epic` or `milestone`. Afterwards the node shows as a work item with that kind,
   status `todo` and the chosen owner (or unassigned).
2. Trying to use any kind other than `story`, `epic` or `milestone` is rejected with
   an error that names the allowed kinds, and nothing changes.
3. Trying to mark a map's root node as a work item is rejected, and nothing changes.
4. Trying to mark a node that is already a work item is rejected, and the existing
   work item is unchanged.
5. Trying to mark a node on an archived map is rejected, and nothing changes.
6. Trying to mark a node that isn't in the named map is rejected.
7. Marking a node doesn't change its content, branch status, turn or links. Every
   existing mind-map tool returns the same results as before for nodes that aren't
   work items.

**Status transitions**
8. Each transition in the table in 4.2 succeeds when requested by a member, and the
   item's status afterwards is the requested status.
9. Every transition not in the table (e.g. `blocked` → `done`, `todo` → `done`,
   `cancelled` → `in_progress`, `done` → `todo`) is rejected with an error that
   names the current status and the requested status. The status is unchanged and
   no history entry is added.
10. A transition marked "reason required" in 4.2 is rejected if no reason (or a
    blank one) is given.
11. Asking for the status the item is already in is rejected, and no history entry
    is added.
12. If the caller gives an expected current status that doesn't match the actual
    one, the change is rejected, the status is unchanged and the error reports the
    actual current status.
13. Changing a work item's status doesn't change its branch status (open / resolved
    / dropped). Resolving or dropping its branch doesn't change its work-item
    status.
14. Closing a map leaves the status, kind and owner of all its work items
    unchanged.

**Ownership and kind**
15. A member can assign a work item to a write-capable member of the map's team,
    reassign it to another one, or unassign it. Each of these is visible straight
    away when the item is read.
16. Assigning to a viewer, a vendor, or someone who isn't on the map's team is
    rejected, and the owner is unchanged.
17. A member can change a work item's kind to any of the other two kinds. Changing
    to the same kind is rejected with no history entry.
18. On an archived map, a member can still change an existing work item's status,
    owner and kind.

**Permissions and isolation**
19. A viewer can list and read work items and their history, but any attempt to
    mark, change status, change kind or assign is rejected with a permission error,
    and nothing changes.
20. A user who isn't on the map's team can't see the map's work items in any
    listing, read or history, and gets the same response as for a map that doesn't
    exist. They can't change them either.
21. Work items in one tenant are never visible to, or changeable by, another tenant.

**Listing**
22. A user can list the work items in one map and filter them by status, kind and
    owner (including "unassigned").
23. A user can list work items across all maps of a team they can read, with the
    same filters plus "assigned to me". Each result shows the kind, status, owner,
    a short title (from the node's content), the map it belongs to, and when it last
    changed.
24. Listings never include nodes that aren't work items, and they include work items
    on both live and archived maps unless the caller filters by map state.

**Audit trail**
25. After any successful creation, status change, owner change or kind change, the
    item's history has exactly one new entry. That entry shows what changed, the
    before and after values, the person who made the change, the channel (agent/MCP
    or web), the time, and the reason if one was given.
26. Rejected attempts add no history entry.
27. The history is returned oldest-first, and the last entry's "after" values
    always match the item's current state.
28. No tool or screen lets anyone edit or delete a history entry, including team
    admins.
29. Given only a work item's history, a reader can work out who owned it on any
    past date and how long it spent in each status. Every change has a time, and no
    gaps or overwrites are possible.
30. An assignee who is later removed from the team still appears by identity in the
    history and as the current owner until reassigned.

**Agent (MCP) surface**
31. Everything in criteria 1–29 that a member can do is available to an agent
    through the Memsys MCP tools. Each tool rejects bad input with the same style of
    structured error the existing mind-map tools use.
32. Reading a map through the existing map-inspection tool shows which nodes are
    work items, with their kind, status and owner, without a separate call for each
    node.

**Web UI**
33. In the web UI's mind-map view, work-item nodes are visually distinct from plain
    nodes and show their kind, status and owner.
34. The web UI has a team-wide work-item list with the filters from criterion 23.
35. Selecting a work item in the web UI shows its full history (criterion 25
    fields), oldest-first.
36. A work item changed through the agent appears in the web UI with its new state
    and history entry the next time the page loads.

## 6. Out of scope (v1)

- **Changing work items from the web UI.** In v1 the web UI only displays them; all
  changes go through the MCP tools. (Web editing is the obvious next step, and the
  history's "channel" field already allows for it.)
- **Hierarchy between kinds.** The system doesn't enforce epics containing stories,
  milestones containing epics, or roll-up of progress / status.
- **Un-marking a node.** A work item can't be turned back into a plain node.
  `cancelled` is the way out, and it keeps the history.
- **Custom statuses, custom kinds or per-team workflows.**
- **Due dates, estimates/story points, priority, labels, sprints, dependencies
  between work items.**
- **More than one assignee, watchers, "only the assignee may close it" rules.**
- **Notifications** (email, push, reminders) when a status or owner changes.
- **Work items outside mind maps** (on plain flat memories) or across maps (one item
  in several maps).
- **Sync with external trackers** (Jira, Linear, GitHub Issues), import or export.
- **Automatic status changes** based on map activity, branch resolution or
  graduation. Memsys has no intelligence by design, so status only changes when a
  person or agent explicitly changes it.
- **Reporting / dashboards** beyond the lists and history above (burndown,
  velocity, cycle-time charts).

## 7. Open questions for the owner (decided provisionally above, confirm before build)

1. Archived maps allow status/owner/kind changes on existing items but no new items
   (4.3). Confirm that work continuing after a map is archived is the intended use.
2. Should the agent be allowed to change status on its own, or only when the person
   tells it to? This brief allows it, with the channel recorded; the
   mindmap-driver skill may need guidance on this.
3. Is "assignee" acceptable as the user-facing word, to avoid confusion with the
   existing owner/model "turn" vocabulary?
