# Work order 1: add `slugify_title` helper

## Goal
Create a new module `src/mem_mcp/util_text.py` exposing:

```python
def slugify_title(title: str) -> str: ...
```

Behaviour (in this order):
1. Lowercase and trim surrounding whitespace.
2. Replace every run of one or more characters that are NOT ASCII `[a-z0-9]` with a single hyphen `-`.
   (Use an ASCII-only regex like `[^a-z0-9]+` — non-ASCII letters such as `é`, `ü`, `日` are treated as
   separators/dropped. Do not add any dependency; do not transliterate.)
3. Strip leading/trailing hyphens.
4. Return the result (may be `""`, e.g. for empty / all-punctuation / all-non-ASCII input).

Examples: `"Hello World"` -> `"hello-world"`; `"  Foo!!!  Bar---Baz  "` -> `"foo-bar-baz"`;
`""` -> `""`; `"!!!"` -> `""`; `"Café au lait"` -> `"caf-au-lait"`; `"日本語"` -> `""`;
`"Version 2.0"` -> `"version-2-0"`.

Follow CONVENTIONS.md: `from __future__ import annotations`, module docstring explaining purpose and
the ASCII-only choice, full type hints, precompiled module-level regex.

## Tests
Add `tests/unit/test_util_text.py` (pure unit tests, no DB) covering: normal text, punctuation runs
(including leading/trailing punctuation and mixed whitespace/hyphens), empty string, whitespace-only,
digits, and unicode letters (assert the exact output, e.g. the examples above). Parametrize where natural.

## Acceptance
- `pytest tests/unit/test_util_text.py -q` passes.
- `ruff check src/mem_mcp/util_text.py tests/unit/test_util_text.py` and `ruff format --check` on those files clean.
- `mypy` reports no new errors for the new module.
- Touch no other files.

Report the commands you ran and their results.
