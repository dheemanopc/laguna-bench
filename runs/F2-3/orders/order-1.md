You are the engineer for the feature below and you do all of the work: investigation, design, implementation,
tests and verification. An architect reviews every stage before you move on, so present your work clearly. Nobody
answers questions mid-stage: if something is ambiguous, state your interpretation and the alternatives in your document.
Shell: run commands plainly (no output redirection, no pipes into files); create files with the Write tool.

STAGE 1 — ANALYSIS (what should change). Do NOT write code yet. Investigate the codebase and write docs/feature/01-analysis.md:
1) every requirement in the request, restated in your own words (one line each, numbered R1..Rn) — none may be dropped;
2) the components affected (tables and constraints, services, MCP tools, web API, web UI pages) with file paths;
3) existing behaviour or constraints that the feature collides with (with file:line);
4) risks and open questions with your recommended answer. Then end your turn.

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
