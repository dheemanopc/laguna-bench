You are reviewing a teammate's finished task. Do NOT edit any file. Task WP3-T1: Team workflows router: make_workflows_router (get/create/activate/remap/pending-signoffs) + main.py registration
Acceptance: make_workflows_router defined in web/handlers/workflows.py and included in main.py at main.py:567 (import at main.py:102); 5 endpoints present: GET/POST /teams/{team_id}/workflow, POST .../{workflow_id}/activate, POST .../remap, GET .../pending-signoffs; GET/POST create/activate/remap/pending-signoffs delegate to the correct WP2 tool, mapping team_id and workflow_id path params into the input model; all endpoints build ToolContext via _ctx_from_session (reused from mindmaps.py) and translate JsonRpcError via _http_from_jsonrpc (400 with code/data); without a valid mem_session cookie, every endpoint returns 401; unit test mocks each tool and asserts (a) 401 without session, (b) correct input-model construction from path params, (c) JsonRpcError.code surfaces in the 400 detail
Package plan: `docs/feature/wp3.md` (DESIGN section). Changed files: src/mem_mcp/web/handlers/workflows.py, src/mem_mcp/main.py, tests/unit/test_web_workflows_router.py
Read the changes (`git diff HEAD -- <files>` and new files) and check them against the acceptance and the plan: wrong
behaviour, missing cases, broken interface promised to other packages, tests that do not really test the behaviour,
weakened checks (noqa, type: ignore, skip). Ignore style.
Final message, exactly:
VERDICT: OK | ISSUES
1. <finding with file:line> (at most 5; none when OK)
