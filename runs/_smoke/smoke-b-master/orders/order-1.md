# Work order 1: add `slugify_title` helper

## Goal
Create a new module `src/mem_mcp/util_text.py` exposing:

```python
def slugify_title(title: str) -> str: ...
```

Behaviour, in order:
1. Lowercase and trim surrounding whitespace.
2. Replace every run of characters that are NOT ASCII `[a-z0-9]` with a single `-`.
   (Non-ASCII letters such as `é`, `ü`, `日本` are treated as non-alphanumeric and therefore dropped/collapsed
   into hyphens. Use an ASCII-only regex like `[^a-z0-9]+` — do not use `\W`, which is Unicode-aware.)
3. Strip leading/trailing hyphens.
Empty or all-punctuation input returns `""`.

Follow CONVENTIONS.md: `from __future__ import annotations`, full type hints, module docstring explaining purpose,
function docstring, precompiled module-level regex. Pure function, no dependencies beyond stdlib.

## Tests
Add `tests/unit/test_util_text.py` (plain pytest, no DB fixtures) covering at least:
- normal text: `"Hello World"` -> `"hello-world"`
- trimming/whitespace: `"  Spaced   Out  "` -> `"spaced-out"`
- punctuation runs: `"Hello, World!!! -- again?"` -> `"hello-world-again"`
- leading/trailing punctuation: `"--Foo--"` -> `"foo"`
- digits kept: `"Version 2.0"` -> `"version-2-0"`
- empty string -> `""`; whitespace-only -> `""`; punctuation-only `"!!!"` -> `""`
- unicode letters: `"Café Déjà Vu"` -> `"caf-d-j-vu"`; `"日本語"` -> `""`
- idempotence: slugifying a slug returns it unchanged
(`pytest.mark.parametrize` is fine.)

## Acceptance / verification
- `pytest tests/unit/test_util_text.py -q` passes.
- `ruff check src/mem_mcp/util_text.py tests/unit/test_util_text.py` and `ruff format --check` on those files clean.
- `mypy` reports no errors for the new module.
- Do not touch any other files.
