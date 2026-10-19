## Gate for wp5-t2b-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 10 passed, 44 warnings in 10.51s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 25:+    pytest.mark.skipif(not os.environ.get("MEM_MCP_TEST_DSN"), reason="MEM_MCP_TEST_DSN unset"),
RESULT: FAIL
