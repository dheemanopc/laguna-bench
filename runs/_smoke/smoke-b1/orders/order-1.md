Smoke test work order.
1. Create the file `scratch/hello_bench.py` containing a function `add(a: int, b: int) -> int` that returns a + b.
2. Create `tests/unit/test_hello_bench.py` with a pytest test for it (import via `from scratch.hello_bench import add` is NOT possible since scratch is not a package — instead put the function in `src/mem_mcp/hello_bench.py` and import `from mem_mcp.hello_bench import add`; delete nothing else).
3. Run `pytest tests/unit/test_hello_bench.py -q` and report the result.
