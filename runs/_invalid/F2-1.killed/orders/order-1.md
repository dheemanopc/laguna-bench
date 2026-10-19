You are the engineer responsible for this task end to end: understand the requirements and the codebase,
design the solution, implement it, write tests, and verify it. Nobody will review your code before scoring.

Business questions: the requirements below come from the product owner. If, after reading the relevant code and
docs, something in the requirements is genuinely ambiguous or conflicts with existing behaviour or the design docs,
write your questions (numbered, each with the options you see and your recommended choice) to QUESTIONS.md in the
repository root and END YOUR TURN without implementing; the answers will be sent to you. Ask only if the answer
would change what you build. Otherwise proceed and record any assumptions in your final report.

When finished, reply with a short report: what you changed, how you verified it (commands + results), assumptions.

Before writing code, write your own design for this feature to docs/design/team-workflows.md (data model, rules, interfaces, UI, migration
of existing data, test plan, open risks). Nobody will approve it: continue straight into implementation and keep the
doc in sync if you change your mind.

=== TASK ===
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
