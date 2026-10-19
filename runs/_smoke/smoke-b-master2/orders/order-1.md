# Work order 1: `slugify_title` helper

## Goal
Add a new pure-function module `src/mem_mcp/util_text.py` exposing:

```python
def slugify_title(title: str) -> str: ...
```

Behaviour:
1. Lowercase and trim (strip surrounding whitespace).
2. Replace every run of characters that are NOT ASCII `[a-z0-9]` with a single hyphen `-`.
   (Non-ASCII letters such as `é`, `ü`, `日本` are treated as non-alphanumeric and may therefore be dropped/collapsed into hyphens. Use an explicit ASCII regex like `re.compile(r"[^a-z0-9]+")` so behaviour is deterministic — do NOT use `\W`/`str.isalnum`, which accept unicode.)
3. Strip leading/trailing hyphens.
4. Empty string (or a string with no ASCII alphanumerics, e.g. `"!!!"`, `"   "`) returns `""`.

Keep it small: module docstring, `from __future__ import annotations` if other modules in the package use it, precompiled module-level regex, function docstring, full type hints. Follow CONVENTIONS.md naming/style. No other source files should change.

## Tests
Create `tests/unit/test_util_text.py` (match style of existing unit tests, pure unit tests, no DB fixtures). Cover at least:
- normal text: `"Hello World"` -> `"hello-world"`; mixed case + digits, e.g. `"Release 2 Notes"` -> `"release-2-notes"`
- punctuation runs: `"Hello,   World!!!"` -> `"hello-world"`; `"a--b__c..d"` -> `"a-b-c-d"`
- leading/trailing whitespace & punctuation: `"  --Hello--  "` -> `"hello"`
- empty string -> `""`; whitespace-only and punctuation-only -> `""`
- unicode letters: `"Café au lait"` -> `"caf-au-lait"`; `"日本語"` -> `""`; `"naïve résumé"` -> `"na-ve-r-sum"`
- idempotence: `slugify_title(slugify_title(x)) == slugify_title(x)` for a sample
Use `pytest.mark.parametrize` where natural.

## Acceptance / verification
- `pytest tests/unit/test_util_text.py -q` — all pass.
- `ruff check src/mem_mcp/util_text.py tests/unit/test_util_text.py` — clean (also `ruff format --check` on both if the project uses ruff format).
- `mypy` (project config) — no new errors in the new module.
- Report commands and results.
