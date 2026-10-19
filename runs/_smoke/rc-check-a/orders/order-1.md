# Work order 1: `slugify_title` text helper

## Goal
Add a new module `src/mem_mcp/util_text.py` with a pure function:

```python
def slugify_title(title: str) -> str: ...
```

Behaviour:
1. Lowercase and trim (strip surrounding whitespace).
2. Replace every run of one or more non-alphanumeric characters with a single hyphen `-`.
   "Alphanumeric" means ASCII `[a-z0-9]` — non-ASCII letters may be dropped (treated as separators).
   Use a precompiled module-level regex constant (UPPER_CASE), e.g. `_NON_ALNUM_RE = re.compile(r"[^a-z0-9]+")`
   (private constant naming per CONVENTIONS is fine either way; keep it at module top).
3. Strip leading/trailing hyphens.
4. Empty input, whitespace-only, or punctuation-only input returns `""`.

Examples: `"Hello World"` → `"hello-world"`; `"  Foo -- Bar!!  baz  "` → `"foo-bar-baz"`; `"---"` → `""`;
`""` → `""`; `"Café Déjà Vu"` → `"caf-d-j-vu"` (accented letters dropped); `"Version 2.0 Release"` → `"version-2-0-release"`.

## Conventions (see CONVENTIONS.md "Style")
- `from __future__ import annotations`, full type hints, module docstring explaining purpose and the
  choice to restrict to ASCII alphanumerics (non-ASCII letters are dropped). Short function docstring.
- No DB, no I/O, no new dependencies.

## Tests
Create `tests/unit/test_util_text.py` (DB-free, plain sync pytest functions; `pytest.mark.parametrize` welcome) covering:
- normal text (mixed case, leading/trailing whitespace),
- punctuation runs collapse to a single hyphen, and leading/trailing punctuation is stripped,
- digits preserved,
- empty string, whitespace-only and punctuation-only → `""`,
- unicode letters (e.g. `"Café"`, `"Ünïcödé Title"`, a purely non-ASCII string like `"日本語"` → `""`): assert exact output,
- result never contains `--` and never starts/ends with `-` (can be a parametrized property check).

## Acceptance / verification
Run and report exact output:
- `pytest tests/unit/test_util_text.py -q`
- `ruff check src/mem_mcp/util_text.py tests/unit/test_util_text.py`
- `ruff format --check src/mem_mcp/util_text.py tests/unit/test_util_text.py`
- `mypy src/mem_mcp/util_text.py` (or `mypy` per project config; report result for the new module)

Do not modify any other files. Do not commit.
