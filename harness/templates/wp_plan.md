You are planning ONE work package of a feature in this repository. The feature goal and the work-package list are in
`docs/feature/00-goal.md` (approved). Read it, then read only the code you need for THIS package.
{DEP_DOCS}
TASK: write `docs/feature/{WPLOW}.md` for **{WPID}: {WPTITLE}** — one level of planning only (package → tasks):
1. DESIGN — at most ~40 lines: what this package changes, the exact interfaces it provides to later packages (signatures,
   endpoints with request/response shape and error codes, columns), and the existing patterns it follows (path:line).
2. TASKS — each task is built later by a fresh engineer session with a ~100k-token budget, so size each task small:
   at most ~3 source files plus its test file, roughly ≤400 changed lines. Tasks run in parallel when their files do not
   overlap, so give every file exactly one owning task where you can.
End the document with a fenced ```json block exactly like:
{"tasks":[{"id":"{WPID}-T1","title":"...","files":["src/...","tests/..."],"tests":["tests/..."],
 "deps":["{WPID}-T0 or another package id like WP0"],"acceptance":["2-4 checkable statements"],"context":["files the engineer should read first"]}]}
Rules for the JSON: "files" are exact repo paths the task creates or modifies (tests included); "tests" are the test files
the harness will run for this task (existing or new, must be in "files" if new); "deps" are task ids or package ids that
must be finished first. Do NOT write code in this task.

{RULES}
