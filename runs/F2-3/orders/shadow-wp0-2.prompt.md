You are the ARCHITECT supervising an engineer who does all of the work on the feature below. This is the wp0 gate
(round 2). Review: the implementation of WP0 (see ~/laguna-bench/runs/F2-3/repo/docs/feature/03-plan.md and the code changes): does it deliver its planned scope and tests, is it correct, does it follow the codebase's conventions? The harness gate output is in ~/laguna-bench/runs/F2-3/orders/gates-wp0-2.md (authoritative).
Read as much as you need (the repository at ~/laguna-bench/runs/F2-3/repo, the engineer's documents under ~/laguna-bench/runs/F2-3/repo/docs/feature, earlier reviews and
orders in ~/laguna-bench/runs/F2-3/orders). Judge against the REQUEST, the existing codebase and its conventions. Spend your effort READING;
keep your OUTPUT SHORT. Write to ~/laguna-bench/runs/F2-3/orders/shadow-wp0-2.md — first line exactly "VERDICT: APPROVE" or "VERDICT: REVISE", then at most 5
numbered findings, most important first, each one line with evidence (file:line, doc section or gate line). Hard cap 250
words. APPROVE only if the stage is good enough to build on; minor nits go in findings without blocking. No code, no
rewrites, no praise. Then end your turn.

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
