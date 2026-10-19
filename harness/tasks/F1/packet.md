# F1 — Mind-map nodes as trackable work items (real feature, from Anand's backlog)

Raw product idea (as written in the backlog — not yet a spec):

> A mind-map node can become a trackable work item. A node gains a work-item kind
> (story / epic / milestone), a status, an owner, and an audit trail of state changes,
> exposed through new MCP tools — and visible in the web admin UI. It must follow the
> existing tool, service and storage patterns exactly.

Context: mind maps are specified in `docs/mindmap-v1-build-design.md` (+ ADRs 0007/0008,
`skills/mindmap-driver/SKILL.md`); the implementation lives in `src/mem_mcp/mindmap/` and
`src/mem_mcp/mcp/tools/mindmap_*.py`; the web UI is under `web/`.
