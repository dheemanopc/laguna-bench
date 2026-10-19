You are reviewing a teammate's finished task. Do NOT edit any file. Task WP5-R1: fix WP5 review findings
Acceptance: #1 tests/unit/test_web_mindmaps_work_items_router.py::test_signoff_error_codes (about line 127-152) now fails. The cause is an earlier handler change, not a bug: signoff_work_item in src/mem_mcp/web/handlers/mindmaps.py:342-377 now opens system_tx(pool) to look up the request's tenant, then runs a tenant_tx check that the request belongs to the path's map_key and node_id. The test passes pool=MagicMock() and does not patch system_tx, so the call fails before the expected 400 with code 'signoff_required'. This is a justified, narrow test update; the handler change stays. Patch mem_mcp.db.system_tx (or wherever the handler imports it) with an async context manager whose fetchrow returns {'tenant_id': TENANT}. Keep the tenant_tx mock returning req_node_id=nid and req_map_key='m'. Keep the assertions as they are. Also add a test that a node_id or map_key mismatch returns 404. Then rerun the full suite and confirm there are no new failures against known red.
Package plan: `docs/feature/wp5.md` (DESIGN section). Changed files: tests/integration/test_mindmap_workflow_web_e2e.py, tests/integration/test_mindmap_workflows_e2e.py, tests/unit/mindmap/test_workflow.py, tests/unit/mindmap/test_workflow_signoff.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
