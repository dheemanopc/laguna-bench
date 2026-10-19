## Gate for wp5-t2b-a3 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 11 passed, 45 warnings in 10.26s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 25:+    pytest.mark.skipif(not os.getenv("MEM_MCP_TEST_DSN"), reason="MEM_MCP_TEST_DSN not set"),
RESULT: FAIL
