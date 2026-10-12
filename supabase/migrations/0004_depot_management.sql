-- Depot Distribution — depot lifecycle management (superadmin)
--
-- Run after 0003. Adds the RPCs the superadmin's "Dépôts" screen needs on top of
-- `depot_create`: edit, activate/deactivate, delete-when-empty, and per-depot
-- statistics.
--
-- The `depots` table is authoritative. `admin_create_user` refuses to bind a
-- user to a depot that is missing or not 'active', and `depot_of_user` /
-- `is_unrestricted` read it, so names and status changes MUST update the table
-- as well as the synced row. A client-side edit of the synced document alone
-- would leave the table stale and the two views would drift. Every RPC here
-- therefore writes the table and republishes the row into `sync_documents`, so
-- every device converges on its next pull.
--
-- Deletion is only allowed for a depot that has no accounts and no synced rows
-- of any other collection. A depot that still holds data is refused with
-- `depot_not_empty`; use deactivation (`status = 'inactive'`) instead, which
-- stops new accounts from being bound to it while preserving its history.

-- ---------------------------------------------------------------------------
-- Preflight: this migration builds on the `depots` table and its helpers,
-- which are created by 0003_multi_depot_superadmin.sql.
-- ---------------------------------------------------------------------------

-- Fail with an actionable message instead of the cryptic
-- "type public.depots does not exist" that appears when 0003 was skipped or
-- rolled back.
do $$
begin
  if to_regclass('public.depots') is null then
    raise exception
      'public.depots is missing: apply 0003_multi_depot_superadmin.sql before 0004_depot_management.sql'
      using errcode = '42704';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Publish a depot row into sync_documents (shared by the RPCs below)
-- ---------------------------------------------------------------------------

-- Upserts the synced `depots` document for [p_depot] and bumps its version so
-- depot-scoped admins and the superadmin see the change. `depot_id` is the
-- depot's own id, so a depot admin's pull (own depot + NULL rows) picks it up.
create or replace function public.depot_publish(p_depot public.depots)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.sync_documents (collection, id, data, version, updated_at, depot_id)
  values (
    'depots',
    p_depot.id::text,
    jsonb_build_object(
      'id',        p_depot.id::text,
      'name',      p_depot.name,
      'city',      p_depot.city,
      'address',   p_depot.address,
      'status',    p_depot.status,
      'createdAt', to_char(p_depot.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt', to_char(p_depot.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    ),
    1,
    now(),
    p_depot.id
  )
  on conflict (collection, id) do update
    set data       = excluded.data,
        version    = public.sync_documents.version + 1,
        updated_at = now(),
        depot_id   = excluded.depot_id;
end;
$$;

revoke all on function public.depot_publish(public.depots) from public;

-- ---------------------------------------------------------------------------
-- depot_update: rename / re-address a depot
-- ---------------------------------------------------------------------------

create or replace function public.depot_update(
  p_id      uuid,
  p_name    text,
  p_city    text default '',
  p_address text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_depot public.depots%rowtype;
begin
  if not public.is_unrestricted() then
    raise exception 'superadmin_only' using errcode = '42501';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name_required' using errcode = '22023';
  end if;

  update public.depots
     set name       = trim(p_name),
         city       = coalesce(p_city, ''),
         address    = coalesce(p_address, ''),
         updated_at = now()
   where id = p_id
   returning * into v_depot;

  if not found then
    raise exception 'depot_not_found' using errcode = 'P0002';
  end if;

  perform public.depot_publish(v_depot);

  return jsonb_build_object(
    'id',      v_depot.id,
    'name',    v_depot.name,
    'city',    v_depot.city,
    'address', v_depot.address,
    'status',  v_depot.status
  );
end;
$$;

revoke all on function public.depot_update(uuid, text, text, text) from public;
grant execute on function public.depot_update(uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- depot_set_status: activate / deactivate a depot
-- ---------------------------------------------------------------------------

-- Deactivating stops `admin_create_user` from binding new accounts to the depot
-- (it requires an 'active' depot). Existing accounts and data are untouched, so
-- the depot can be reactivated at any time.
create or replace function public.depot_set_status(
  p_id     uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_depot public.depots%rowtype;
begin
  if not public.is_unrestricted() then
    raise exception 'superadmin_only' using errcode = '42501';
  end if;

  if p_status is null or p_status not in ('active', 'inactive') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;

  update public.depots
     set status     = p_status,
         updated_at = now()
   where id = p_id
   returning * into v_depot;

  if not found then
    raise exception 'depot_not_found' using errcode = 'P0002';
  end if;

  perform public.depot_publish(v_depot);

  return jsonb_build_object('id', v_depot.id, 'status', v_depot.status);
end;
$$;

revoke all on function public.depot_set_status(uuid, text) from public;
grant execute on function public.depot_set_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- depot_delete: remove a depot that holds nothing
-- ---------------------------------------------------------------------------

-- Refuses when the depot still has accounts or synced rows of any other
-- collection, so nothing is ever orphaned. The tombstone is published with a
-- NULL depot_id (every depot's pull includes NULL rows, and the depot row it
-- would otherwise reference is about to be deleted) and then the row is dropped.
create or replace function public.depot_delete(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_depot public.depots%rowtype;
begin
  if not public.is_unrestricted() then
    raise exception 'superadmin_only' using errcode = '42501';
  end if;

  select * into v_depot from public.depots where id = p_id;
  if not found then
    raise exception 'depot_not_found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.app_users where depot_id = p_id) then
    raise exception 'depot_not_empty' using errcode = '23503';
  end if;

  if exists (
    select 1
    from public.sync_documents
    where depot_id = p_id
      and not (collection = 'depots' and id = p_id::text)
  ) then
    raise exception 'depot_not_empty' using errcode = '23503';
  end if;

  insert into public.sync_documents (collection, id, data, version, updated_at, deleted, depot_id)
  values (
    'depots',
    p_id::text,
    jsonb_build_object('id', p_id::text, 'name', v_depot.name),
    1,
    now(),
    true,
    null
  )
  on conflict (collection, id) do update
    set data       = excluded.data,
        version    = public.sync_documents.version + 1,
        updated_at = now(),
        deleted    = true,
        depot_id   = null;

  delete from public.depots where id = p_id;

  return jsonb_build_object('id', p_id);
end;
$$;

revoke all on function public.depot_delete(uuid) from public;
grant execute on function public.depot_delete(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- depot_stats: headline counts for the depot detail screen
-- ---------------------------------------------------------------------------

-- Counts are read from the authoritative tables (accounts) and from the synced
-- rows (everything else) scoped to the depot, so the superadmin sees exactly
-- what the depot owns without trusting any client.
create or replace function public.depot_stats(p_depot_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_unrestricted() then
    raise exception 'superadmin_only' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'admins',     (select count(*) from public.app_users
                    where depot_id = p_depot_id and role = 'admin'),
    'drivers',    (select count(*) from public.app_users
                    where depot_id = p_depot_id and role = 'driver'),
    'products',   (select count(*) from public.sync_documents
                    where collection = 'products'   and depot_id = p_depot_id and not deleted),
    'categories', (select count(*) from public.sync_documents
                    where collection = 'categories' and depot_id = p_depot_id and not deleted),
    'orders',     (select count(*) from public.sync_documents
                    where collection = 'orders'     and depot_id = p_depot_id and not deleted),
    'deliveries', (select count(*) from public.sync_documents
                    where collection = 'deliveries' and depot_id = p_depot_id and not deleted),
    'routes',     (select count(*) from public.sync_documents
                    where collection = 'routes'     and depot_id = p_depot_id and not deleted),
    'inventory',  (select count(*) from public.sync_documents
                    where collection = 'inventory'  and depot_id = p_depot_id and not deleted),
    'movements',  (select count(*) from public.sync_documents
                    where collection = 'movements'  and depot_id = p_depot_id and not deleted)
  );
end;
$$;

revoke all on function public.depot_stats(uuid) from public;
grant execute on function public.depot_stats(uuid) to authenticated;
