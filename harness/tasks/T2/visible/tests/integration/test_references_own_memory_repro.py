"""Repro: referencing one of my OWN memories fails with memory_not_accessible.

Reported from the PMO plugin: a user whose account was provisioned the
"natural" way (raw-SQL provisioning, as the 0026 personal-team backfill did —
not via the team-management API) writes memory M1, can read M1 back with
memory_get, but a second write that cites M1 via `references=[...]` is
rejected with `memory_not_accessible`.

Run:  pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py
"""

from __future__ import annotations

from typing import Any
from uuid import UUID, uuid4

import pytest

from mem_mcp.mcp.tools.write import ReferenceInput

pytestmark = pytest.mark.asyncio


async def _provision_user_like_backfill(conn: Any) -> dict[str, Any]:
    """Tenant + personal team + owner assignment + primary identity, all via raw SQL
    (the way the 0026 backfill provisioned existing users)."""
    tenant = await conn.fetchval(
        "INSERT INTO tenants (email) VALUES ($1) RETURNING id",
        f"repro-{uuid4()}@example.test",
    )
    team = await conn.fetchval(
        "INSERT INTO teams (name, created_by_tenant_id, team_type) "
        "VALUES ($1, $2, 'personal') RETURNING id",
        f"repro-{uuid4().hex[:8]}",
        tenant,
    )
    owner_role_id = await conn.fetchval(
        "SELECT id FROM roles_catalog WHERE role_key = 'owner' AND plugin_id IS NULL"
    )
    await conn.execute(
        """
        INSERT INTO team_role_assignments
            (parent_team_id, member_kind, member_id, role_id, status, assigned_by_user_id)
        VALUES ($1, 'user', $2, $3, 'active', $2)
        """,
        team,
        tenant,
        owner_role_id,
    )
    await conn.execute(
        """
        INSERT INTO tenant_identities
        (tenant_id, cognito_sub, provider, email, is_primary, default_team_id)
        VALUES ($1, $2, 'cognito', $3, true, $4)
        """,
        tenant,
        f"sub-repro-{tenant}",
        f"repro-{tenant}@example.test",
        team,
    )
    await conn.execute(
        """
        INSERT INTO oauth_clients
        (id, redirect_uris, scope, registration_payload, review_status)
        VALUES ($1, ARRAY[]::text[], 'memory.read memory.write',
                '{}'::jsonb, 'auto_allowed')
        ON CONFLICT (id) DO NOTHING
        """,
        "plugin:repro-own-ref",
    )
    return {"tenant": tenant, "team": team}


async def _cleanup(pool: Any, tenant: UUID, team: UUID) -> None:
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute(
                """
                DELETE FROM memory_references
                WHERE source_memory_id IN (SELECT id FROM memories WHERE tenant_id = $1)
                   OR target_memory_id IN (SELECT id FROM memories WHERE tenant_id = $1)
                """,
                tenant,
            )
            await conn.execute("DELETE FROM slugs WHERE team_id = $1", team)
            await conn.execute("DELETE FROM memories WHERE tenant_id = $1", tenant)
            await conn.execute("DELETE FROM team_role_assignments WHERE parent_team_id = $1", team)
            await conn.execute("DELETE FROM tenant_identities WHERE tenant_id = $1", tenant)
            await conn.execute("DELETE FROM teams WHERE id = $1", team)
            await conn.execute("DELETE FROM tenants WHERE id = $1", tenant)


async def test_citing_my_own_readable_memory_succeeds(
    pg_pool: Any, sdk_client_factory: Any
) -> None:
    async with pg_pool.acquire() as conn:
        async with conn.transaction():
            setup = await _provision_user_like_backfill(conn)
    try:
        sdk = sdk_client_factory(tenant_id=setup["tenant"], plugin_id="repro-own-ref")

        target_id = await sdk.write(content="target memory for ref", type="note")
        assert target_id is not None

        # The memory is readable by its owner...
        got = await sdk.get(memory_id=target_id)
        assert got is not None
        assert str(got["id"]) == str(target_id)

        # ...so citing it from a new memory of the same user must work.
        # Currently raises PluginValidationError(code="memory_not_accessible").
        citer_id = await sdk.write(
            content="citer memory with reference",
            type="note",
            references=[ReferenceInput(target_uuid=UUID(str(target_id)), reference_kind="cites")],
        )
        assert citer_id is not None

        async with pg_pool.acquire() as vconn:
            n = await vconn.fetchval(
                "SELECT COUNT(*) FROM memory_references "
                "WHERE source_memory_id = $1 AND target_memory_id = $2",
                UUID(str(citer_id)),
                UUID(str(target_id)),
            )
        assert n == 1
    finally:
        await _cleanup(pg_pool, setup["tenant"], setup["team"])
