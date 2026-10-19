You are the architect and product owner for a feature in ~/laguna-bench/runs/F2-4/repo. Local-model engineers (Laguna) plan and build it; a
Sonnet delivery lead reviews and routes; a harness runs the gates. You are consulted only a few times in this one
session: to sign off the goal, to settle escalations, and for the final acceptance. Spend tokens on READING, keep your
OUTPUT short (no code, no praise). Always end with exactly one fenced ```json block in the format asked, nothing after.
The request:
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



EVENT goal_signoff. The engineers' goal document is `~/laguna-bench/runs/F2-4/repo/docs/feature/00-goal.md`; the delivery lead approved it
(its notes: R3 says sign-off from someone other than the OWNER, but the rules exclude only the PROPOSER. Pick one: exclude both the item owner and the proposer, and state it in WP1.; R6 'waiting on you' has no read path. Add a pending-signoffs-for-me query to WP1, plus an MCP tool and a web endpoint, so the board and agents show the same list.; allowed_moves and blocked_reason are only read from the move response, so the board can't show them before a move is tried. WP1 needs a read function that returns them per item, and WP2 and WP3 need to expose it, including in work_list and the board list.; Backfill and legacy-workflow materialisation are ambiguous: the goal says both 'first reference' (lazy) and 'backfill existing rows' (in the migration). Choose one. Lazy materialisation is simpler and safe, and WP0 should state which one it does.; The set_work_item_status routing for workflowed items appears only under Risks. Put it in WP1/WP2 as a deliverable with a test in WP5, so sign-off can't be bypassed.). Sign off only if the plan would deliver the request; at most 5 findings.
Reply json: {"verdict":"APPROVE|REVISE","findings":["..."]}