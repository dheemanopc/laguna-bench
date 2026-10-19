# Task: tiny utility (smoke test)
Add a small helper `slugify_title(title: str) -> str` to a new module `src/mem_mcp/util_text.py` that lowercases,
trims, replaces runs of non-alphanumeric characters with a single hyphen, and strips leading/trailing hyphens.
Add unit tests in `tests/unit/test_util_text.py` covering normal text, punctuation runs, empty string, and unicode letters
(non-ASCII letters may be dropped). All new tests must pass.
