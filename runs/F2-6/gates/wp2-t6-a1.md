## Gate for wp2-t6-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 4 passed in 1.90s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 302:+    pytest.mark.skipif(not os.getenv("MEM_MCP_TEST_DSN"), reason="MEM_MCP_TEST_DSN not set"),
RESULT: FAIL
