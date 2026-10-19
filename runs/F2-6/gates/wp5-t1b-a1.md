## Gate for wp5-t1b-a1 (harness-run)
- ruff: clean
- mypy (this task's files): clean
- tests: 10 passed in 3.17s
- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):
    added: 44:+    pytest.mark.skipif(not os.environ.get("MEM_MCP_TEST_DSN"), reason="needs test database"),
RESULT: FAIL
