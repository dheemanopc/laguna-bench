You are the product owner doing the final ACCEPTANCE of this feature. The original request is below. The engineer worked
alone. Read whatever you need: the repository at ~/laguna-bench/runs/F2-2/repo (its design doc docs/design/team-workflows.md, code, migrations, tests,
web UI), the change summary ~/laguna-bench/runs/F2-2/orders/delivered.stat, and the order/answer files in ~/laguna-bench/runs/F2-2/orders. You cannot run anything;
judge from the code and tests. Spend your effort READING; keep your OUTPUT SHORT (hard cap ~400 words). Write to
~/laguna-bench/runs/F2-2/orders/ACCEPTANCE.md: 1) verdict ACCEPT / ACCEPT WITH FIXES / REJECT; 2) a table: requirement (your reading of the
request) | MET / PARTLY / NOT MET | evidence (file:line or test name); 3) design soundness, at most 5 bullets; 4) up to 5
defects that matter to users, most severe first. No rewrites, no code, no praise. Then end your turn.

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
