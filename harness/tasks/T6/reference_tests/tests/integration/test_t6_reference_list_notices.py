"""T6 calibration tests (written by the task author, NOT given to executors).

Used only to (1) prove the mutmut harness works with DB-backed tests in
reasonable time and (2) give a reference kill rate above the floor.
"""

from __future__ import annotations

import asyncio
import json
from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import pytest

from mem_mcp.mcp.errors import JsonRpcError
from mem_mcp.mcp.tools._base import ToolContext
from mem_mcp.mcp.tools.list import MemoryListInput, MemoryListTool
from mem_mcp.mcp.tools.write import MemoryWriteInput, MemoryWriteTool
from mem_mcp.plugins.clients.notices import NoticeClientImpl
from mem_mcp.plugins.notice_delivery import deliver_pending
from mem_mcp.teams.assignments import assign_role

pytestmark = pytest.mark.asyncio


def _deps() -> Any:
    from mem_mcp.audit.logger import NoopAuditLogger
    from mem_mcp.mcp.tools._deps import NoopQuotas, ToolDeps

    class _StubEmbed:
        async def embed(self, content: str) -> Any:
            from mem_mcp.embeddings.bedrock import EmbedResult

            return EmbedResult(vector=[0.01] * 1024, input_tokens=1)

    return ToolDeps(embeddings=_StubEmbed(), audit=NoopAuditLogger(), quotas=NoopQuotas())


async def _tenant(pool: Any) -> tuple[UUID, UUID]:
    async with pool.acquire() as conn, conn.transaction():
        tenant = await conn.fetchval(
            "INSERT INTO tenants (email) VALUES ($1) RETURNING id", f"t6-{uuid4()}@example.test"
        )
        team = await conn.fetchval(
            "INSERT INTO teams (name, created_by_tenant_id) VALUES ($1, $2) RETURNING id",
            f"t6-{uuid4().hex[:8]}",
            tenant,
        )
        await assign_role(
            conn,
            parent_team_id=team,
            member_kind="user",
            member_id=tenant,
            role_key="member",
            assigned_by_user_id=tenant,
        )
        await conn.execute(
            "INSERT INTO tenant_identities (tenant_id, cognito_sub, provider, email, is_primary,"
            " default_team_id) VALUES ($1, $2, 'cognito', $3, true, $4)",
            tenant,
            f"sub-{tenant}",
            f"t6-{tenant}@example.test",
            team,
        )
        await conn.execute(
            "INSERT INTO oauth_clients (id, redirect_uris, scope, registration_payload,"
            " review_status) VALUES ('t6-client', ARRAY[]::text[], 'memory.read memory.write',"
            " '{}'::jsonb, 'auto_allowed') ON CONFLICT (id) DO NOTHING"
        )
    return tenant, team


def _ctx(pool: Any, tenant: UUID) -> ToolContext:
    return ToolContext(
        request_id="r",
        tenant_id=tenant,
        identity_id=tenant,
        client_id="t6-client",
        scopes=frozenset({"memory.read", "memory.write"}),
        db_pool=pool,
        deps=_deps(),
    )


async def _w(ctx: ToolContext, content: str, **kw: Any) -> UUID:
    out = await MemoryWriteTool()(ctx, MemoryWriteInput(content=content, force_new=True, **kw))
    return out.id  # type: ignore[attr-defined,no-any-return]


async def _ls(ctx: ToolContext, **kw: Any) -> Any:
    return await MemoryListTool()(ctx, MemoryListInput(**kw))


async def test_filters(pg_pool: Any) -> None:
    tenant, team = await _tenant(pg_pool)
    ctx = _ctx(pg_pool, tenant)
    a = await _w(ctx, "alpha apples note", tags=["x", "y"])
    b = await _w(ctx, "beta bananas decision", type="decision", tags=["x"])
    c = await _w(ctx, "gamma cherries", tags=["y"], indexable=False)
    d = await _w(ctx, "delta reply", parent_id=a)
    e = await _w(ctx, "epsilon expired", expires_at=datetime.now(UTC) + timedelta(seconds=1))
    async with pg_pool.acquire() as conn:
        await conn.execute("UPDATE memories SET expires_at = now() - interval '1 hour' WHERE id=$1", e)
        await conn.execute("UPDATE memories SET deleted_at = now() WHERE id=$1", c)

    ids = lambda out: {r.id for r in out.results}  # noqa: E731
    assert ids(await _ls(ctx)) == {a, b, d}
    both = await _ls(ctx, tags=["x", "y"])
    assert a in ids(both) and b not in ids(both)
    assert all({"x", "y"} <= set(r.tags) for r in both.results)
    only_x = await _ls(ctx, tags=["x"])
    assert {a, b} <= ids(only_x) and all("x" in r.tags for r in only_x.results)
    assert ids(await _ls(ctx, type="decision")) == {b}
    assert ids(await _ls(ctx, include_deleted=True)) == {a, b, c, d}
    assert ids(await _ls(ctx, include_expired=True)) == {a, b, d, e}
    assert ids(await _ls(ctx, include_deleted=True, indexable=False)) == {c}
    assert ids(await _ls(ctx, parent_id=a)) == {d}
    assert ids(await _ls(ctx, team_id=team)) == {a, b, d}
    assert ids(await _ls(ctx, team_id=uuid4())) == set()
    assert ids(await _ls(ctx, keywords="bananas")) == {b}
    kw = await _ls(ctx, keywords="bananas")
    assert "**" in kw.results[0].preview
    plain = {r.id: r for r in (await _ls(ctx, type="note", tags=["x"])).results}
    assert plain[a].preview == "alpha apples note" and "**" not in plain[a].preview
    future = datetime.now(UTC) + timedelta(days=1)
    assert ids(await _ls(ctx, since=future)) == set()
    assert ids(await _ls(ctx, until=future)) == {a, b, d}
    past = datetime.now(UTC) - timedelta(days=1)
    assert ids(await _ls(ctx, until=past)) == set()
    assert ids(await _ls(ctx, since=past)) == {a, b, d}
    # history
    async with pg_pool.acquire() as conn:
        await conn.execute("UPDATE memories SET is_current=false WHERE id=$1", b)
    assert b not in ids(await _ls(ctx))
    assert b in ids(await _ls(ctx, include_history=True))
    # other tenant sees nothing of ours
    t2, _ = await _tenant(pg_pool)
    assert ids(await _ls(_ctx(pg_pool, t2))) == set()


async def test_order_and_pagination(pg_pool: Any) -> None:
    tenant, _ = await _tenant(pg_pool)
    ctx = _ctx(pg_pool, tenant)
    made = []
    for i in range(5):
        made.append(await _w(ctx, f"item {i}"))
        await asyncio.sleep(0.01)
    desc = [r.id for r in (await _ls(ctx)).results]
    assert desc == list(reversed(made))
    asc = [r.id for r in (await _ls(ctx, order="asc")).results]
    assert asc == made
    upd = [r.id for r in (await _ls(ctx, order_by="updated_at", order="asc")).results]
    assert upd == made
    page = await _ls(ctx, limit=2)
    assert len(page.results) == 2 and page.next_cursor
    last = await _ls(ctx, limit=5)
    assert last.next_cursor is None
    with pytest.raises(JsonRpcError) as exc:
        await _ls(ctx, cursor="not-a-cursor!!")
    assert exc.value.code == -32602


@pytest.mark.xfail(strict=True, reason="BUG: any cursor page crashes (ISO string bound to timestamptz); also cursor is taken from the overflow row")
async def test_pagination_visits_every_row(pg_pool: Any) -> None:
    tenant, _ = await _tenant(pg_pool)
    ctx = _ctx(pg_pool, tenant)
    made = []
    for i in range(5):
        made.append(await _w(ctx, f"row {i}"))
        await asyncio.sleep(0.01)
    seen: list[UUID] = []
    cursor = None
    for _ in range(10):
        out = await _ls(ctx, limit=2, cursor=cursor, order="asc")
        seen += [r.id for r in out.results]
        cursor = out.next_cursor
        if cursor is None:
            break
    assert seen == made


async def test_notices_roundtrip(pg_pool: Any) -> None:
    tenant, _ = await _tenant(pg_pool)
    other, _ = await _tenant(pg_pool)
    client = NoticeClientImpl(pg_pool, tenant, "remind")
    when = datetime(2026, 1, 2, 3, 4, 5, tzinfo=UTC)
    rid = uuid4()
    await client.queue("reminders.due", "Due {title} at {fire_at} ({missing})",
                       {"title": "pay rent", "fire_at": when, "day": date(2026, 1, 2), "rid": rid})
    await asyncio.sleep(0.01)
    await client.queue("reminders.due", "second {title}", {"title": "two"})
    await client.queue("x", "expired", {}, ttl_seconds=-5)
    await NoticeClientImpl(pg_pool, other, "remind").queue("x", "other {a}", {"a": 1})

    async with pg_pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT payload, expires_at - created_at AS ttl FROM plugin_notices"
            " WHERE tenant_id=$1 ORDER BY created_at LIMIT 1", tenant)
        payload = row["payload"] if isinstance(row["payload"], dict) else json.loads(row["payload"])
        assert payload == {"title": "pay rent", "fire_at": when.isoformat(), "day": "2026-01-02", "rid": str(rid)}
        assert timedelta(hours=23, minutes=59) < row["ttl"] <= timedelta(days=1, seconds=1)
        first = await deliver_pending(conn, tenant, limit=1)
        assert [n.text for n in first] == [f"Due pay rent at {when.isoformat()} ()"]
        d = first[0].to_dict()
        assert d["plugin_id"] == "remind" and d["kind"] == "reminders.due"
        assert d["id"] == str(first[0].id) and d["payload"]["title"] == "pay rent"
        assert d["created_at"] == first[0].created_at.isoformat()
        rest = await deliver_pending(conn, tenant)
        assert [n.text for n in rest] == ["second two"]
        assert await deliver_pending(conn, tenant) == []
        theirs = await deliver_pending(conn, other)
        assert [n.text for n in theirs] == ["other 1"]
