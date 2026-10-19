# ACCEPTANCE — F1: Mind-map nodes as trackable work items (round F1-1)

Reviewer: Product Owner. Date: 2026-10-16.

## Overall verdict: **REJECT**

Nothing was delivered this round. No acceptance criterion can be accepted.

## What I checked

| Item | Finding |
|---|---|
| `orders/DESIGN.md` | **Missing.** The orders directory has no design file. Its contents are `BRIEF.md`, `known_red_base.txt`, the prompt files and `.da.env`. There are no dev order files either. |
| `feature.diff` | **Empty** (0 bytes). |
| Repository code | No trace of the feature. A case-insensitive search for `work_item` / `workitem` across the whole repo (src, tests, alembic, web UI) finds nothing. The git snapshot at the start of the session shows a clean tree on the single `baseline` commit. |
| Tech lead's report | It does not claim to deliver any work package. It says the round stopped at the first command because the Bash tool was denied. No design was written, no developers were dispatched and nothing was reviewed. |

Limitation: Bash was also denied to me in this review, so I could not run `git diff`, `git status` or the test suite myself. I relied on file reads and searches, and they agree with the empty diff and the tech lead's account.

## Claimed acceptance criteria

The round claims **none**, so nothing gets a MET / PARTLY / NOT MET verdict for delivered work. For the record, all 36 criteria in BRIEF §5 are currently **NOT MET**:

| Criteria | Area | Status | Evidence |
|---|---|---|---|
| 1–7 | Marking nodes as work | NOT MET | No code, schema or tool exists (`feature.diff` empty) |
| 8–14 | Status transitions | NOT MET | No transition table and no enforcement exists |
| 15–18 | Ownership and kind | NOT MET | Nothing exists |
| 19–21 | Permissions and isolation | NOT MET | Nothing exists |
| 22–24 | Listing | NOT MET | Nothing exists |
| 25–30 | Audit trail | NOT MET | Nothing exists |
| 31–32 | Agent (MCP) surface | NOT MET | No `mindmap_*` work-item tools; map inspection unchanged |
| 33–36 | Web UI | NOT MET | No changes under the `/mindmaps` UI |

## Places where the design or code contradicts business intent

None can be judged, because there is no design and no code. One process observation: the brief was handed over as "ready for design", but the open questions in BRIEF §7 were never put to me. Those are archived-map edits, the agent changing status on its own, and the word "assignee". Product answers them here so the next round can start without waiting:

1. **Archived maps:** confirmed. Existing items stay editable (status, assignee, kind). New items can't be created on an archived map.
2. **Agent autonomy:** the agent may change status itself. The channel (MCP) must be recorded on every history entry, as AC 25 requires. Guidance for the mindmap-driver skill ("confirm with the person before closing statuses") is welcome but isn't an acceptance gate.
3. **Terminology:** confirmed. Use "assignee" in all user-facing text (MCP tool descriptions, errors, web UI). Keep "owner" for the turn vocabulary only.

## Still missing for the whole feature

Everything:

1. **DESIGN.md**, covering the data model (a work-item record attached to a node; an append-only history table that RLS/grants make immutable), the Alembic migration, the service layer, MCP tools, map-inspection changes and web UI views, all following `CONVENTIONS.md`.
2. **Schema and migration** for work items and their append-only history. Tenant and team isolation (AC 20–21) and immutability (AC 28) must be enforced in the database.
3. **Domain rules:** the kind enum, the five-status transition table with reason-required edges, the same-status rejection, the expected-status concurrency check, no work item on the root node, no creation on archived maps, and assignees restricted to write-capable team members.
4. **MCP tools:** mark, change status, change kind, assign/unassign, list per map, list per team (filters plus "assigned to me"), and history. Errors must use the existing mind-map structured style (AC 31).
5. **Map-inspection enrichment:** work-item kind, status and assignee shown inline (AC 32).
6. **Web UI:** work-item nodes marked on the map, a team-wide list with filters, and a history view, all read-only (AC 33–36).
7. **Tests** covering every criterion. In particular: every allowed and disallowed transition (AC 8–12), branch and map independence (AC 13–14), the viewer/vendor/non-member/cross-tenant matrix (AC 19–21), exactly one history entry per successful change and none on rejection (AC 25–27), and a removed-member assignee (AC 30). Existing mind-map tool results for nodes that aren't work items must stay unchanged (AC 7).
8. **Verification evidence:** pytest, ruff, mypy and `alembic upgrade head` results, with no new failures beyond `known_red_base.txt`.

## What the next round needs

This is a blocked process, not a quality failure. The orchestration environment has to give the tech lead Bash, at least for `dispatch_devs.sh`, `git`, `pytest`, `ruff`, `mypy` and `alembic`. Without it, no round can produce or verify code. Once that is fixed, re-run F1 from design.
