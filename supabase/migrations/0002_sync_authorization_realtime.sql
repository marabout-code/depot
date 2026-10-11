-- Depot Distribution — server-side sync authorization + realtime
--
-- Run once in the Supabase SQL editor, or with `supabase db push`.

-- ---------------------------------------------------------------------------
-- sync_push_rows: authorize every row by role before applying it
-- ---------------------------------------------------------------------------
-- Previously any authenticated depot user could push rows to any collection, so
-- a driver device could rewrite products, prices, stock, or another driver's
-- orders. This version keeps the version-based last-write-wins rule but first
-- restricts what a non-admin may touch:
--
--   * orders / deliveries / routes : only rows assigned to the caller
--                           (driverId = uid)
--   * users               : only the caller's own row, and never its
--                           role/status/offline hash
--   * products / inventory / movements / categories : admin only
--
-- Unauthorized rows are skipped silently: the caller's device treats the row as
-- pushed and the next pull restores the server's copy, so a device can never
-- write outside its scope.
create or replace function public.sync_push_rows(
  p_collection text,
  p_rows       jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row      jsonb;
  v_data     jsonb;
  v_accepted jsonb := '[]'::jsonb;
  v_is_admin boolean;
  v_uid      text := auth.uid()::text;
  v_role     text;
  v_status   text;
  v_offline  text;
begin
  if v_uid is null
     or not exists (select 1 from public.app_users u where u.id = auth.uid()) then
    raise exception 'not_a_depot_user' using errcode = '42501';
  end if;

  if p_collection not in (
    'users', 'products', 'orders', 'deliveries',
    'inventory', 'movements', 'categories', 'routes'
  ) then
    raise exception 'unknown_collection' using errcode = '42501';
  end if;

  v_is_admin := public.is_admin();

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    if v_is_admin then
      v_data := coalesce(v_row -> 'data', '{}'::jsonb);
    else
      if p_collection in ('orders', 'deliveries', 'routes') then
        -- Drivers may only touch deliveries/routes assigned to them.
        if coalesce(v_row -> 'data' ->> 'driverId', '') <> v_uid then
          continue;
        end if;
        v_data := coalesce(v_row -> 'data', '{}'::jsonb);
      elsif p_collection = 'users' then
        -- Drivers may edit their own profile but never escalate their role,
        -- flip their status, or overwrite the offline PIN hash. Those fields
        -- are forced back to the authoritative values.
        if coalesce(v_row ->> 'id', '') <> v_uid then
          continue;
        end if;
        select role, status, pin_offline_hash
          into v_role, v_status, v_offline
          from public.app_users
         where id = auth.uid();
        v_data := coalesce(v_row -> 'data', '{}'::jsonb) || jsonb_build_object(
          'id',             v_uid,
          'role',           v_role,
          'status',         v_status,
          'offlinePinHash', v_offline
        );
      else
        -- Drivers cannot write reference or stock data.
        continue;
      end if;
    end if;

    if exists (
      select 1
      from public.sync_documents d
      where d.collection = p_collection
        and d.id = (v_row ->> 'id')
        and (
          d.version > (v_row ->> 'version')::integer
          or (
            d.version = (v_row ->> 'version')::integer
            and d.updated_at > coalesce(
              nullif((v_row ->> 'updatedAt')::timestamptz, 'epoch'),
              'epoch'::timestamptz
            )
          )
        )
    ) then
      continue;
    end if;

    insert into public.sync_documents
      (collection, id, data, version, deleted, updated_at, pushed_by)
    values (
      p_collection,
      v_row ->> 'id',
      v_data,
      (v_row ->> 'version')::integer,
      coalesce((v_row ->> 'deleted')::boolean, false),
      coalesce(nullif((v_row ->> 'updatedAt')::timestamptz, 'epoch'), now()),
      auth.uid()
    )
    on conflict (collection, id) do update
      set data       = excluded.data,
          version    = excluded.version,
          deleted    = excluded.deleted,
          updated_at = excluded.updated_at,
          pushed_by  = auth.uid()
    where public.sync_documents.version <= excluded.version;

    v_accepted := v_accepted || jsonb_build_array(jsonb_build_object(
      'id',      v_row ->> 'id',
      'version', (v_row ->> 'version')::integer
    ));
  end loop;

  return v_accepted;
end;
$$;

revoke all on function public.sync_push_rows(text, jsonb) from public;
grant execute on function public.sync_push_rows(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime on sync_documents
-- ---------------------------------------------------------------------------
-- Lets a device react to another device's write immediately instead of waiting
-- for its next poll: the admin sees a delivery completed, a driver sees a new
-- assignment. Clients only use the event as a trigger for a normal sync pass,
-- so RLS still decides what each user can actually read.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'sync_documents'
     )
  then
    execute 'alter publication supabase_realtime add table public.sync_documents';
  end if;
end $$;
