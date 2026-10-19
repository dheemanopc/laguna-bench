# Work order 1: `slugify_title` text helper

## Goal
Create a new module `src/mem_mcp/util_text.py` exposing:

```python
def slugify_title(title: str) -> str: ...
```

Behaviour, applied in this order:
1. Trim surrounding whitespace and lowercase.
2. Replace every run of one or more characters that are **not ASCII `[a-z0-9]`** with a single hyphen `-`.
   (Non-ASCII letters such as `é`, `ß`, `日` are treated as non-alphanumeric and so dropped / turned
   into separators. That is intended; do not transliterate, and do not add dependencies.)
3. Strip leading and trailing hyphens.

Examples: `"Hello World"` -> `"hello-world"`; `"  Foo -- Bar!!! baz  "` -> `"foo-bar-baz"`;
`""` -> `""`; `"!!!"` -> `""`; `"Café Crème"` -> `"caf-cr-me"`; `"日本語"` -> `""`; `"Version 2.0"` -> `"version-2-0"`.

Use a precompiled module-level regex, e.g. `re.compile(r"[^a-z0-9]+")` (with lowercasing done first;
note `str.lower()` can produce non-ASCII output, which the regex then handles).

## Conventions (see CONVENTIONS.md "Style")
- `from __future__ import annotations`, full type hints, ruff-formatted (~100 cols).
- Module docstring explaining purpose and the why of the ASCII-only choice; short function docstring.
- No other files changed besides the two below.

## Tests
Create `tests/unit/test_util_text.py` (follow the style of existing tests in `tests/unit/`) covering at least:
- normal text (`"Hello World"`),
- punctuation/whitespace runs collapsing to one hyphen, plus leading/trailing hyphen stripping,
- empty string and whitespace-only / punctuation-only input -> `""`,
- unicode letters (non-ASCII dropped, e.g. `"Café Crème"` -> `"caf-cr-me"`, `"日本語"` -> `""`),
- digits preserved and an already-slugified input is unchanged (idempotent).
`pytest.mark.parametrize` is fine.

## Acceptance / verification — report exact output of:
- `pytest tests/unit/test_util_text.py -q`
- `ruff check src tests` and `ruff format --check src/mem_mcp/util_text.py tests/unit/test_util_text.py`
- `mypy` (note whether any errors are in the new files)
- `pytest -q` (full suite; report pass/fail counts and confirm any failures are pre-existing/unrelated)
