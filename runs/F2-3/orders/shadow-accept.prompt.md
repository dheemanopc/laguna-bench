You are the product owner doing the final ACCEPTANCE of this feature. Read whatever you need: the repository at
~/laguna-bench/runs/F2-3/repo (the engineer's documents under docs/feature, code, migrations, tests, web UI), the architect's reviews and the harness
gate output (~/laguna-bench/runs/F2-3/orders/gates-final.md) in ~/laguna-bench/runs/F2-3/orders. Spend your effort READING; keep OUTPUT SHORT (hard cap ~400 words).
Write to ~/laguna-bench/runs/F2-3/orders/SHADOW-ACCEPTANCE.md: 1) verdict ACCEPT / ACCEPT WITH FIXES / REJECT; 2) table: requirement | MET / PARTLY /
NOT MET | evidence; 3) up to 5 defects that matter to users, most severe first. No code, no praise. Then end your turn.

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
