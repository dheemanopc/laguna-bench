You are the lead engineer for a new feature in this repository (Python MCP server + Postgres + Next.js web app under
web/). You plan it, then other engineers (fresh sessions, one task each, several in parallel) build it from your plan.
Nobody has implemented this before. Read CLAUDE.md and CONVENTIONS.md first.

TASK: write the feature GOAL document `docs/feature/00-goal.md` — ONE level of planning only (feature → work packages).
Explore just enough of the codebase to get this right (data model, the existing work-item code, MCP tool and web handler
patterns, the web app layout). Keep the document under ~120 lines:
1. GOAL — 3-5 lines: what "done" means for the whole feature, stated so it can be checked.
2. REQUIREMENTS — R1..Rn, one line each; none of the request may be dropped.
3. KEY DECISIONS — data model (tables/columns/constraints only), rules, how existing data and in-flight items are handled,
   auth/visibility. Name the existing files/patterns you will follow (path:line).
4. WORK PACKAGES — in build order. For each: `### WPn: title`, 2-4 lines of scope, the requirements it delivers, its
   INTERFACE to later packages (function signatures / endpoints / table columns it provides), depends_on.
   Typical split: migration; domain/services; MCP tools; web API; web UI; verification. Keep every database migration in
   ONE package (WP0) because migrations cannot be built in parallel.
5. RISKS — at most 5 lines.
End the document with a fenced ```json block exactly like:
{"wps":[{"id":"WP0","title":"...","depends_on":[],"exclusive":true}, {"id":"WP1","title":"...","depends_on":["WP0"],"exclusive":false}]}
("exclusive": true = nothing else may run while its tasks run, e.g. migrations.)
Do NOT write code in this task.

## Rules (always apply)
DO
- Work ONLY on the files listed for your task. If you truly must touch another file, keep the change minimal and name it
  under NOTES with the reason.
- Find code with Grep first, then Read only the parts you need (use offset/limit). Your session has a hard budget of
  about 100k tokens of context; it is stopped beyond that, so do not read whole large files or dump big outputs.
- Run the tests named in your task (`pytest <files> -q`). If you changed or added a migration, run `alembic upgrade head`
  first. The harness re-runs every check itself; your claims are not trusted, so report results verbatim.
- If something is ambiguous, decide, follow the existing code's conventions, and record the assumption under NOTES.
- Web docs are allowed when you need them (GET only): `curl -sL <url>` or WebFetch, on pypi.org, docs.python.org,
  fastapi.tiangolo.com, docs.sqlalchemy.org, alembic.sqlalchemy.org, magicstack.github.io (asyncpg), www.postgresql.org,
  nextjs.org, react.dev, www.typescriptlang.org, playwright.dev, www.npmjs.com, raw.githubusercontent.com, github.com.
DON'T
- Never weaken a check to get green: no `# noqa`, no `type: ignore`, no `pytest.mark.skip/xfail`, no edits to lint or
  type-check config (pyproject tool sections, tools/lint_*.py, tsconfig, eslint), no deleting or loosening existing tests.
  If an existing test conflicts with the planned behaviour, say so under NOTES instead.
- Don't ask questions or wait for answers: nobody replies mid-task.
- Don't redirect output into files outside the repo; create files with the Write tool; run commands plainly.
- Don't send data anywhere (no POST/upload); never read or print credentials or .env files.
- Don't start other work beyond your task.

## Response format (your FINAL message, exactly these headings, nothing else)
RESULT: DONE | BLOCKED
CHANGED: <comma-separated repo paths you created or modified>
TESTS: <each command you ran> -> <its last summary line, verbatim>
CHECKLIST: <only when fixing findings: one line per finding "#<n> FIXED <where>" or "#<n> NOT FIXED <why>">
NOTES: <at most 5 short lines: assumptions, deviations, follow-ups; "none" if none>


=== REQUEST ===
# F2 — Team workflows for work items (real feature, from Anand's backlog)

Raw product idea (as written in the backlog — not yet a spec):

> Mind-map work items exist now, but every team works differently. A team should be able to define
> its own workflow — the stages a work item moves through, which moves are allowed, and what a move
> needs before it happens (for example a reason, or sign-off from someone other than the owner,
> possibly from more than one person). Items should never get stuck or lose their history when a
> team changes its workflow. People need to see and move their team's work on a board in the web
> app, see why a move is blocked, and see what is waiting on them. Agents must be able to do the
> same through the MCP tools.

Context: work items were added recently (migrations 0046/0047, `src/mem_mcp/mindmap/`, the work-item
MCP tools). Mind maps are described in `docs/mindmap-v1-build-design.md` and the ADRs; the web app is under `web/`.
Follow the existing patterns of this codebase.


REVISION: `docs/feature/00-goal.md` exists; revise it (edit, do not start over) to resolve these findings, then list them under CHECKLIST:
#1 R3/WP1: state one rule. A sign-off must come from someone who is neither the item owner nor the proposer, so neither counts toward signoff_min. The role restriction still applies, and WP5 tests both exclusions.
#2 R6/read path: WP1 adds two reads. One returns allowed_moves, blocked_reason and pending sign-off state per item. The other is a pending-signoffs-for-me query. WP2 exposes both: the per-item fields go into mindmap_work_list/get, and the query becomes a new mindmap_workflow_pending_signoffs tool. WP3 adds the matching board-list and 'waiting on me' endpoints. WP4 reads these and no longer relies on the move response.
#3 WP0/WP1: legacy workflow materialisation is lazy, on first reference inside the domain transaction, and idempotent under concurrency. The migration does not backfill work_items. Items with a null workflow_id resolve to the legacy workflow, with current_stage taken from status. WP0 says this explicitly, and so does the WP0 title in the plan's own JSON.
#4 WP1/WP2/WP5: the existing set-status, mark and MCP set_status paths are a deliverable, not a risk. For items with a workflow they route through move_work_item/propose_move, or reject with MoveBlockedError. WP5 tests that a sign-off-gated move cannot be done through set_status from either MCP or web.
#5 WP0 history/schema: work_items.status and work_item_history (change_type, status_after NOT NULL) only accept the legacy values from 0046. WP0 must record custom-stage moves, e.g. a 'stage' change_type with stage_before/stage_after and workflow_id, plus sign-off request and approval events. It must define what status holds for custom stages, and index (tenant_id, team_id, current_stage) for the board.