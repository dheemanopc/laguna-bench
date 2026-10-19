You are planning ONE work package of a feature in this repository. The feature goal and the work-package list are in
`docs/feature/00-goal.md` (approved). Read it, then read only the code you need for THIS package.
Plans of the packages you build on (read their DESIGN sections): docs/feature/wp0.md

TASK: write `docs/feature/wp1.md` for **WP1: Domain service (workflow.py + work_items move/route)** — one level of planning only (package → tasks):
1. DESIGN — at most ~40 lines: what this package changes, the exact interfaces it provides to later packages (signatures,
   endpoints with request/response shape and error codes, columns), and the existing patterns it follows (path:line).
2. TASKS — each task is built later by a fresh engineer session with a ~100k-token budget, so size each task small:
   at most ~3 source files plus its test file, roughly ≤400 changed lines. Tasks run in parallel when their files do not
   overlap, so give every file exactly one owning task where you can.
End the document with a fenced ```json block exactly like:
{"tasks":[{"id":"WP1-T1","title":"...","files":["src/...","tests/..."],"tests":["tests/..."],
 "deps":["WP1-T0 or another package id like WP0"],"acceptance":["2-4 checkable statements"],"context":["files the engineer should read first"]}]}
Rules for the JSON: "files" are exact repo paths the task creates or modifies (tests included); "tests" are the test files
the harness will run for this task (existing or new, must be in "files" if new); "deps" are task ids or package ids that
must be finished first. Do NOT write code in this task.

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


REVISION: your plan exists; revise it (edit) to resolve these findings, list them under CHECKLIST:
#1 workflow.py is owned by T1, T2 and T4. Split it into separate modules (CRUD and legacy, moves, reads) or merge the tasks, so each file has one owner.
#2 T1–T4 have no tests and everything is deferred to one large T5. Give each task its own test file. WP5-T1 also claims test_workflow.py, so remove it from one of the two plans.
#3 compute_item_moves needs blocked_reason and pending sign-off state in its return type, plus a viewing-user argument for role_restricted and 'waiting on me'. propose_move also lacks map_key and channel.
#4 materialise_legacy_workflow conflicts with the one-active-workflow-per-team index. Conflict on (team_id, name) and keep the legacy workflow inactive. Also add a shared errors module, since work_items.py and workflow.py would import each other.
#5 T3 routes assign_work_item, which the goal does not list, and the acceptance text says move_workitem. create_team_workflow and remap_workflow_stages have no permission check.