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

{RULES}

=== REQUEST ===
{PACKET}
