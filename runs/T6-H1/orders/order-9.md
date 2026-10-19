# Work order 9 — memory_list DB: field round-trip, include flags, limit edge (TESTS ONLY, small)

Keep output short. Edits only in `tests/integration/test_memory_list_filters_db.py`.

0. Tighten `test_keywords_filter_order_and_preview`: replace the `or` assertion (around line 158) with
   two exact ones: `"**postgres**" in result.results[0].preview` (m4 "the postgres planner") and
   `"**Postgres**" in result.results[1].preview` (m1 "Postgres runs fast"). In the no-keywords loop,
   also assert `item.content == <original content for that id>` (map id → original).
1. `test_item_fields_round_trip` — check the `embedding_status` CHECK constraint values in alembic
   first. Insert one memory with: type="fact", tags=[x, y] (uuid-suffixed), version=3,
   is_current=True, indexable=False, embedding_status=<a valid value other than "ok">,
   expires_at=datetime(2099,1,1,tzinfo=UTC), created_at=datetime(2026,1,2,tzinfo=UTC),
   updated_at=datetime(2026,1,3,tzinfo=UTC), content="round trip body". List with defaults and
   assert the single item: `id`, `content == "round trip body"`, `preview == "round trip body"`,
   `type == "fact"`, `tags == [x, y]`, `version == 3`, `is_current is True`, `created_at`, `updated_at`,
   `deleted_at is None`, `expires_at`, `indexable is False`, `embedding_status`. (If `indexable=False`
   rows are excluded by default, that's a finding — show me.)
   Second memory with `deleted_at=datetime(2026,2,2,tzinfo=UTC)` → appears only with
   `include_deleted=True`, and its `deleted_at` equals that value exactly.
2. `test_include_flags_combined` — N normal; D deleted_at=past; E expires_at=`now - 1h`; H is_current=False
   (version=1; give N/H distinct content). Assert id sets: default → {N}; include_deleted → {N, D};
   include_expired → {N, E}; include_history → {N, H}; deleted+expired → {N, D, E};
   all three → {N, D, E, H}. Also a memory F with expires_at = now + 1h is in the default set
   (add F: default → {N, F}, adjust all sets accordingly).
3. `test_limit_one_edge` — one memory A (created_at base): `limit=1` → `[A]`, `next_cursor is None`.
   Add B (created_at base+1min): `limit=1` → `[B]`, `next_cursor is not None`, and
   `_decode_cursor(next_cursor) == (base.isoformat(), str(A))`. `limit=2` → `[B, A]`, cursor None.

Run `pytest -q -p no:cacheprovider tests/integration/test_memory_list_filters_db.py -rxX 2>&1 | tail -15`
and paste verbatim.
