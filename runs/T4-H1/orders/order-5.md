# Work order 5 — revert the extra link event; fix the real cause in SQL

## Root cause (please confirm)
The pool's `_init_connection` (`src/mem_mcp/db/pool.py`) registers a jsonb codec with `encoder=json.dumps`, and
`service.log_event` passes `json.dumps(payload)` → the payload is double-encoded and stored as a jsonb **string
scalar** (`jsonb_typeof(payload) = 'string'`). That's why `payload->>'target'` never matched and you added a
second `link` event in `mindmap_link`. That workaround changes an existing tool's observable behaviour (two
`link` events per link) and is out of scope.

## Changes
1. **Revert** your change to `src/mem_mcp/mcp/tools/mindmap_link.py` completely
   (`git diff src/mem_mcp/mcp/tools/mindmap_link.py` must be empty afterwards).
2. Do **not** change `log_event`'s encoding (existing rows are already string-encoded and readers rely on
   `_as_dict`). Instead make `service.touched_member_ids_since` tolerant of both shapes: normalise the payload in
   SQL, e.g.
   ```sql
   CASE WHEN jsonb_typeof(mme.payload) = 'string'
        THEN (mme.payload #>> '{}')::jsonb
        ELSE mme.payload END ->> 'target'
   ```
   (wrap in a CTE/subquery for readability). Comment *why* in the docstring (codec double-encoding, both shapes
   exist). Keep the join to membership so only members of this map come back.
3. Tests:
   - `test_since_link_touches_both_endpoints`: assert node ids `== {a, b}` exactly (not just "in").
   - New `test_link_logs_single_event` in the e2e file: after one `mindmap_link(map_key=…)`, exactly one `link`
     event exists for that map since the cursor before the link.
   - New service-level test (same e2e file is fine) for `touched_member_ids_since` that inserts one event with a
     proper jsonb **object** payload `{"target": "<member id>"}` directly via SQL (`'{"target": "..."}'::jsonb` as a
     literal string param cast in SQL with `$n::text::jsonb` to bypass the codec — or however you can get an object
     stored) and one string-encoded (via `log_event`), and asserts both targets are returned. Also a payload with a
     non-UUID `target` value doesn't error.
   - Use `monkeypatch.setattr(mindmap_resolve, "insert_reference", boom)` in the atomicity test instead of manual
     save/restore.
4. `ruff format` both test files (several lines > 100 cols) and the migration.

## Verification — paste actual output
1. `git diff --stat` and `git diff src/mem_mcp/mcp/tools/mindmap_link.py` (must be empty).
2. `pytest -q -p no:cacheprovider tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
3. Full-suite comparison (paste the `wc -l` and `comm` output literally):
   ```
   pytest -q -p no:cacheprovider -rfE 2>&1 | tee /tmp/after_full.txt | tail -1
   grep -E '^(FAILED|ERROR) ' /tmp/after_full.txt | sed 's/ - .*//' | sort -u > /tmp/after.txt
   git stash -u
   pytest -q -p no:cacheprovider -rfE 2>&1 | tee /tmp/before_full.txt | tail -1
   grep -E '^(FAILED|ERROR) ' /tmp/before_full.txt | sed 's/ - .*//' | sort -u > /tmp/before.txt
   git stash pop && git status --short
   wc -l /tmp/before.txt /tmp/after.txt; comm -13 /tmp/before.txt /tmp/after.txt
   ```
4. `ruff check src tests`; `ruff format --check` on all new/touched files; `mypy`.
