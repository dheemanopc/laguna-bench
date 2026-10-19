You are the PRODUCT OWNER for a new feature in this repository (Memsys, a team memory service with MCP tools).
Business understanding is your territory; engineers will do design and implementation.
Read enough of the repository docs and code to understand the product and the mind-map feature, then turn the raw
idea below into a business brief. Write it with the Write tool to ~/laguna-bench/runs/F1-1/orders/BRIEF.md and end your turn.

The brief must contain: the problem and who it is for; user stories; the business rules (what a work item is, which
states and transitions make sense, who may change what, what the audit trail must let someone answer); numbered,
testable ACCEPTANCE CRITERIA phrased as observable behaviour; and what is explicitly out of scope.
Do NOT design the implementation (no schemas, no function names, no file plans). Keep it to what a business owner decides.

=== RAW IDEA ===
# F1 — Mind-map nodes as trackable work items (real feature, from Anand's backlog)

Raw product idea (as written in the backlog — not yet a spec):

> A mind-map node can become a trackable work item. A node gains a work-item kind
> (story / epic / milestone), a status, an owner, and an audit trail of state changes,
> exposed through new MCP tools — and visible in the web admin UI. It must follow the
> existing tool, service and storage patterns exactly.

Context: mind maps are specified in `docs/mindmap-v1-build-design.md` (+ ADRs 0007/0008,
`skills/mindmap-driver/SKILL.md`); the implementation lives in `src/mem_mcp/mindmap/` and
`src/mem_mcp/mcp/tools/mindmap_*.py`; the web UI is under `web/`.
