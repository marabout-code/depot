-- Depot Distribution — multi-depot + superadmin
--
-- Run once in the Supabase SQL editor, or with `supabase db push`. Must run
-- after 0002 (it redefines the same functions, so it also works directly after
-- 0001 if 0002 was skipped: each function here is a full `create or replace`).
--
-- One shared installation now hosts several depots. Each depot has its own
-- staff and dataset; a single superadmin manages them all:
--
--   * `app_users.depot_id`   NULL = unrestricted (superadmin, or a legacy admin
--                             created before this migration). Any non-null value
--                             scopes that account to one depot.
--   * `sync_documents.depot_id`   Every synced row belongs to a depot. Rows
--                             this migration leaves with NULL depot are legacy
--                             rows that predate depots; every depot may read and
--                             write them, so no data disappears.
--   * `sync_pull_rows`        A depot-scoped caller pulls only its own rows plus
--                             legacy NULL rows. A superadmin / legacy admin
--                             (NULL depot) pulls everything.
--   * `sync_push_rows`        New rows inherit the caller's depot; existing rows
--                             keep theirs. A depot-scoped caller may only write
--                             its own depot's rows. `depots` rows are authored
--                             only by unrestricted callers and belong to
--                             themselves, so every depot admin sees their own
--                             depot row.
--   * PINs stay globally unique (one PIN, one account, across every depot) so a
--     fresh device can always resolve a PIN unambiguously.
--
-- After this migration the FIRST bootstrap account is a `superadmin` (created
-- without a depot). The existing install's first admin keeps its old role but
-- gets an empty depot_id, which the helpers below treat as "unrestricted" too,
-- so nothing already deployed stops working.

-- ---------------------------------------------------------------------------
-- Depots
-- ---------------------------------------------------------------------------

create table if not exists public.depots (
  id         uuid primary key default gen_random_uuid(),
  name       text        not null,
  city       text        not null default '',
  address    text        not null default '',
  status     text        not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.depots enable row level security;

drop policy if exists depots_select on public.depots;
create policy depots_select on public.depots
  for select to authenticated
  using (public.is_unrestricted() or id = public.depot_of_user(auth.uid()));

drop policy if exists depots_admin_write on public.depots;
create policy depots_admin_write on public.depots
  for all to authenticated
  using (public.is_unrestricted())
  with check (public.is_unrestricted());

-- ---------------------------------------------------------------------------
-- app_users: depot column + widened role check
-- ---------------------------------------------------------------------------

alter table public.app_users
  add column if not exists depot_id uuid references public.depots (id);

alter table public.app_users
  drop constraint if exists app_users_role_check;

alter table public.app_users
  add constraint app_users_role_check
    check (role in ('superadmin', 'admin', 'driver'));

create index if not exists app_users_depot_idx on public.app_users (depot_id);

-- ---------------------------------------------------------------------------
-- sync_documents: depot column
-- ---------------------------------------------------------------------------

alter table public.sync_documents
  add column if not exists depot_id uuid references public.depots (id);

create index if not exists sync_documents_depot_idx
  on public.sync_documents (collection, depot_id);

-- ---------------------------------------------------------------------------
-- Role helpers
-- ---------------------------------------------------------------------------

-- The depot this caller is scoped to, or NULL when unrestricted (superadmin or
-- a legacy admin without a depot). Security definer because app_users is RLS'd.
create or replace function public.depot_of_user(p_uid uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select public.app_users.depot_id
  from public.app_users
  where public.app_users.id = p_uid;
$$;

-- True for a superadmin, or any admin without a depot (legacy). An unrestricted
-- caller manages every depot and reads every dataset.
create or replace function public.is_unrestricted()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid()
      and u.status = 'active'
      and (u.role = 'superadmin' or u.depot_id is null)
  );
$$;

-- Widened: a superadmin is an admin in every sense that matters.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid()
      and u.role in ('admin', 'superadmin')
      and u.status = 'active'
  );
$$;

-- ---------------------------------------------------------------------------
-- app_users RLS: same depot (or legacy null rows) for depot admins, all for
-- unrestricted callers, self always.
-- ---------------------------------------------------------------------------

drop policy if exists app_users_select on public.app_users;
create policy app_users_select on public.app_users
  for select to authenticated
  using (
    id = auth.uid()
    or public.is_unrestricted()
    or (public.is_admin()
        and (depot_id = public.depot_of_user(auth.uid()) or depot_id is null))
  );

drop policy if exists app_users_admin_write on public.app_users;
create policy app_users_admin_write on public.app_users
  for all to authenticated
  using (
    public.is_admin()
    and (public.is_unrestricted()
         or depot_id = public.depot_of_user(auth.uid())
         or depot_id is null)
  )
  with check (
    public.is_admin()
    and (public.is_unrestricted()
         or depot_id = public.depot_of_user(auth.uid()))
  );

-- ---------------------------------------------------------------------------
-- sync_pull_rows: scope the dataset by depot
-- ---------------------------------------------------------------------------

create or replace function public.sync_pull_rows(
  p_collection text,
  p_since      timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_depot uuid;
begin
  if not exists (select 1 from public.app_users u where u.id = auth.uid()) then
    raise exception 'not_a_depot_user' using errcode = '42501';
  end if;

  v_depot := public.depot_of_user(auth.uid());

  -- Unrestricted callers get the full history; everyone else gets their own
  -- depot plus the legacy NULL-depot rows so pre-depot data still syncs.
  if v_depot is null then
    return coalesce((
      select jsonb_agg(jsonb_build_object(
               'id',        d.id,
               'data',      d.data,
               'version',   d.version,
               'deleted',   d.deleted,
               'updatedAt', d.updated_at
             ) order by d.updated_at)
      from public.sync_documents d
      where d.collection = p_collection
        and (p_since is null or d.updated_at > p_since)
    ), '[]'::jsonb);
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id',        d.id,
             'data',      d.data,
             'version',   d.version,
             'deleted',   d.deleted,
             'updatedAt', d.updated_at
           ) order by d.updated_at)
    from public.sync_documents d
    where d.collection = p_collection
      and (p_since is null or d.updated_at > p_since)
      and (d.depot_id = v_depot or d.depot_id is null)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.sync_pull_rows(text, timestamptz) from public;
grant execute on function public.sync_pull_rows(text, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- sync_push_rows: role + depot authorization
-- ---------------------------------------------------------------------------
-- Keeps every 0002 rule and adds depot scoping:
--
--   * new rows inherit the caller's depot; existing rows keep theirs
--   * a depot-scoped caller may only insert rows from its own depot. It may
--     still touch legacy NULL-depot rows (subtle: the admin creating the row
--     for the first time after migration claims it for their depot because the
--     target depot is their own — deliberately not done here. New-row depot is
--     the caller's depot only for genuinely new rows; existing rows keep the
--     NULL they had, staying shared).
--   * `depots` collection: only unrestricted callers may write, and new depot
--     rows belong to the depot id they carry so every depot admin can read its
--     own depot row and the superadmin can read them all.
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
  v_row            jsonb;
  v_data           jsonb;
  v_accepted       jsonb := '[]'::jsonb;
  v_is_admin       boolean;
  v_is_unrestricted boolean;
  v_depot          uuid;
  v_uid            text := auth.uid()::text;
  v_role           text;
  v_status         text;
  v_offline        text;
  v_existing_depot uuid;
  v_target_depot   uuid;
begin
  if v_uid is null
     or not exists (select 1 from public.app_users u where u.id = auth.uid()) then
    raise exception 'not_a_depot_user' using errcode = '42501';
  end if;

  if p_collection not in (
    'users', 'products', 'orders', 'deliveries',
    'inventory', 'movements', 'categories', 'routes', 'depots'
  ) then
    raise exception 'unknown_collection' using errcode = '42501';
  end if;

  v_is_admin        := public.is_admin();
  v_is_unrestricted := public.is_unrestricted();
  v_depot           := public.depot_of_user(auth.uid());

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    -- Resolve which depot the row belongs to. Existing rows keep theirs; new
    -- rows inherit the caller's depot, except depot records which belong to
    -- themselves (their id) and are authored only by unrestricted callers.
    select d.depot_id into v_existing_depot
      from public.sync_documents d
     where d.collection = p_collection
       and d.id = (v_row ->> 'id');

    if v_existing_depot is not null then
      v_target_depot := v_existing_depot;
    elsif p_collection = 'depots' then
      if not v_is_unrestricted then
        continue;
      end if;
      v_target_depot := (v_row ->> 'id')::uuid;
    else
      v_target_depot := v_depot;
    end if;

    if v_is_admin then
      -- Depot records: only an unrestricted caller may write them.
      if p_collection = 'depots' then
        if not v_is_unrestricted then
          continue;
        end if;
      elsif not v_is_unrestricted
        and v_target_depot is not null
        and v_target_depot <> v_depot then
        -- A depot admin may only touch rows of its own depot. Legacy NULL rows
        -- stay writable by any depot admin.
        continue;
      end if;
      v_data := coalesce(v_row -> 'data', '{}'::jsonb);
    else
      if p_collection in ('orders', 'deliveries', 'routes') then
        -- Drivers may only touch assignments that are theirs, and only from
        -- their own depot.
        if coalesce(v_row -> 'data' ->> 'driverId', '') <> v_uid then
          continue;
        end if;
        if v_target_depot is not null and v_target_depot <> v_depot then
          continue;
        end if;
        v_data := coalesce(v_row -> 'data', '{}'::jsonb);
      elsif p_collection = 'users' then
        if coalesce(v_row ->> 'id', '') <> v_uid then
          continue;
        end if;
        if v_target_depot is not null and v_target_depot <> v_depot then
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
          'offlinePinHash', v_offline,
          'depotId',        v_depot::text
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
      (collection, id, data, version, deleted, updated_at, pushed_by, depot_id)
    values (
      p_collection,
      v_row ->> 'id',
      v_data,
      (v_row ->> 'version')::integer,
      coalesce((v_row ->> 'deleted')::boolean, false),
      coalesce(nullif((v_row ->> 'updatedAt')::timestamptz, 'epoch'), now()),
      auth.uid(),
      v_target_depot
    )
    on conflict (collection, id) do update
      set data       = excluded.data,
          version    = excluded.version,
          deleted    = excluded.deleted,
          updated_at = excluded.updated_at,
          pushed_by  = auth.uid(),
          depot_id   = excluded.depot_id
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
-- PIN login: unchanged (PINs are globally unique, one account per PIN)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Admin account management
-- ---------------------------------------------------------------------------

-- Creates a depot account with a hashed PIN. A depot-scoped admin's account is
-- always bound to that admin's own depot; an unrestricted caller (superadmin)
-- must pass p_depot_id for any non-superadmin account and NULL for a
-- superadmin. Returns the generated session secret so the creator can sign in.
create or replace function public.admin_create_user(
  p_email            text,
  p_name             text,
  p_pin              text,
  p_role             text default 'driver',
  p_phone            text default '',
  p_data             jsonb default '{}'::jsonb,
  p_offline_pin_hash text default null,
  p_depot_id         uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid            uuid;
  v_user_id        uuid := gen_random_uuid();
  v_secret         text := encode(gen_random_bytes(32), 'hex');
  v_caller_depot   uuid;
  v_target_depot   uuid;
  v_is_unrestricted boolean;
begin
  if not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  if p_role not in ('superadmin', 'admin', 'driver') then
    raise exception 'invalid_role' using errcode = '22023';
  end if;

  v_caller_depot    := public.depot_of_user(auth.uid());
  v_is_unrestricted := public.is_unrestricted();

  if v_is_unrestricted then
    v_target_depot := p_depot_id;
  else
    v_target_depot := v_caller_depot;
  end if;

  if p_role = 'superadmin' then
    if not v_is_unrestricted then
      raise exception 'superadmin_only' using errcode = '42501';
    end if;
    if v_target_depot is not null then
      raise exception 'superadmin_no_depot' using errcode = '22023';
    end if;
  elsif v_target_depot is null then
    raise exception 'depot_required' using errcode = '42501';
  elsif not exists (
    select 1 from public.depots
    where id = v_target_depot and status = 'active'
  ) then
    raise exception 'depot_not_found' using errcode = '22023';
  end if;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000'::uuid,
    'authenticated',
    'authenticated',
    lower(trim(p_email)),
    crypt(v_secret, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    '', '', '', ''
  )
  on conflict (email) do update
    set encrypted_password = excluded.encrypted_password,
        aud                = excluded.aud,
        role               = excluded.role,
        raw_app_meta_data  = excluded.raw_app_meta_data,
        email_confirmed_at = coalesce(auth.users.email_confirmed_at, excluded.email_confirmed_at),
        updated_at         = now()
  returning id into v_uid;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  )
  values (
    gen_random_uuid(),
    v_uid,
    jsonb_build_object('sub', v_uid::text, 'email', lower(trim(p_email)), 'email_verified', true),
    'email',
    v_uid::text,
    now(), now(), now()
  )
  on conflict do nothing;

  insert into public.app_users (id, name, email, phone, role, status, pin_hash, pin_offline_hash, data, depot_id)
  values (
    v_uid,
    coalesce(p_name, ''),
    lower(trim(p_email)),
    coalesce(p_phone, ''),
    coalesce(p_role, 'driver'),
    'active',
    crypt(p_pin, gen_salt('bf')),
    coalesce(p_offline_pin_hash, null),
    coalesce(p_data, '{}'::jsonb),
    v_target_depot
  )
  on conflict (id) do update
    set name            = excluded.name,
        phone           = excluded.phone,
        role            = excluded.role,
        pin_hash        = excluded.pin_hash,
        pin_offline_hash = excluded.pin_offline_hash,
        data            = excluded.data,
        depot_id        = excluded.depot_id,
        updated_at      = now();

  insert into public.sync_documents (collection, id, data, version, updated_at, depot_id)
  values (
    'users',
    v_uid::text,
    coalesce(p_data, '{}'::jsonb) || jsonb_build_object(
      'id',             v_uid::text,
      'name',           coalesce(p_name, ''),
      'email',          lower(trim(p_email)),
      'phone',          coalesce(p_phone, ''),
      'role',           coalesce(p_role, 'driver'),
      'status',         'active',
      'offlinePinHash', p_offline_pin_hash,
      'depotId',        v_target_depot::text,
      'createdAt',      to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt',      to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    ),
    1,
    now(),
    v_target_depot
  )
  on conflict (collection, id) do update
    set data       = excluded.data,
        version    = public.sync_documents.version + 1,
        updated_at = now();

  return jsonb_build_object(
    'id',     v_uid,
    'email',  lower(trim(p_email)),
    'secret', v_secret
  );
end;
$$;

revoke all on function public.admin_create_user(text, text, text, text, text, jsonb, text, uuid) from public;
grant execute on function public.admin_create_user(text, text, text, text, text, jsonb, text, uuid) to authenticated;

-- Rotates a PIN. A depot-scoped admin may only rotate PINs of users in their
-- own depot (or the legacy NULL-depot rows); an unrestricted caller rotates any.
create or replace function public.admin_set_pin(
  p_user_id          uuid,
  p_pin              text,
  p_offline_pin_hash text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
  end if;

  if not public.is_unrestricted()
     and (select u.depot_id from public.app_users u where u.id = p_user_id)
           is distinct from public.depot_of_user(auth.uid())
     and not exists (
       select 1 from public.app_users u
       where u.id = p_user_id and u.depot_id is null
     )
  then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  update public.app_users
     set pin_hash         = crypt(p_pin, gen_salt('bf')),
         pin_offline_hash = coalesce(p_offline_pin_hash, pin_offline_hash),
         updated_at       = now()
   where id = p_user_id;
end;
$$;

revoke all on function public.admin_set_pin(uuid, text, text) from public;
grant execute on function public.admin_set_pin(uuid, text, text) to authenticated;

-- Publishes a profile row, depot included, so other devices see the new user.
create or replace function public.app_users_sync_upsert(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row public.app_users%rowtype;
begin
  -- An admin may publish their own depot's users (or legacy NULL-depot rows);
  -- a user may always publish their own profile; an unrestricted caller may
  -- publish anyone.
  if not (
    p_user_id = auth.uid()
    or public.is_unrestricted()
    or (
      public.is_admin()
      and (
        exists (select 1 from public.app_users u where u.id = p_user_id and u.depot_id is null)
        or (select u.depot_id from public.app_users u where u.id = p_user_id)
           = public.depot_of_user(auth.uid())
      )
    )
  ) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_row from public.app_users where id = p_user_id;

  if not found then
    raise exception 'row_not_found' using errcode = 'P0002';
  end if;

  insert into public.sync_documents (collection, id, data, version, updated_at, pushed_by, depot_id)
  values (
    'users',
    v_row.id::text,
    (v_row.data || jsonb_build_object(
      'id',             v_row.id::text,
      'name',           v_row.name,
      'email',          v_row.email,
      'phone',          v_row.phone,
      'role',           v_row.role,
      'status',         v_row.status,
      'offlinePinHash', v_row.pin_offline_hash,
      'depotId',        v_row.depot_id::text,
      'createdAt',      to_char(v_row.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt',      to_char(v_row.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    )),
    1,
    now(),
    auth.uid(),
    v_row.depot_id
  )
  on conflict (collection, id) do update
    set data       = excluded.data,
        version    = public.sync_documents.version + 1,
        updated_at = now()
    where public.sync_documents.updated_at <= excluded.updated_at;
end;
$$;

revoke all on function public.app_users_sync_upsert(uuid) from public;
grant execute on function public.app_users_sync_upsert(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Depot RPCs (superadmin only)
-- ---------------------------------------------------------------------------

-- Creates a depot and publishes its row so the superadmin's next pull (and each
-- depot admin's own pull) can resolve it. The synced row carries depot_id = its
-- own id so a depot-scoped caller's pull picks it up.
create or replace function public.depot_create(
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

  insert into public.depots (name, city, address)
  values (trim(p_name), coalesce(p_city, ''), coalesce(p_address, ''))
  returning * into v_depot;

  insert into public.sync_documents (collection, id, data, version, updated_at, depot_id)
  values (
    'depots',
    v_depot.id::text,
    jsonb_build_object(
      'id',        v_depot.id::text,
      'name',      v_depot.name,
      'city',      v_depot.city,
      'address',   v_depot.address,
      'status',    v_depot.status,
      'createdAt', to_char(v_depot.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt', to_char(v_depot.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    ),
    1,
    now(),
    v_depot.id
  );

  return jsonb_build_object(
    'id',      v_depot.id,
    'name',    v_depot.name,
    'city',    v_depot.city,
    'address', v_depot.address
  );
end;
$$;

revoke all on function public.depot_create(text, text, text) from public;
grant execute on function public.depot_create(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: also publish depot rows
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'depots'
     )
  then
    execute 'alter publication supabase_realtime add table public.depots';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- First account bootstrap: the superadmin (no depot)
-- ---------------------------------------------------------------------------

-- Refuses to run once ANY admin or superadmin exists, so it cannot be used to
-- escalate privileges later.
create or replace function public.admin_bootstrap(
  p_email text,
  p_name  text,
  p_pin   text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := gen_random_uuid();
  v_secret  text := encode(gen_random_bytes(32), 'hex');
begin
  if exists (select 1 from public.app_users where role in ('admin', 'superadmin')) then
    raise exception 'admin_already_exists' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  values (
    v_uid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    'authenticated',
    'authenticated',
    lower(trim(p_email)),
    crypt(v_secret, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  )
  values (
    gen_random_uuid(),
    v_uid,
    jsonb_build_object('sub', v_uid::text, 'email', lower(trim(p_email)), 'email_verified', true),
    'email',
    v_uid::text,
    now(), now(), now()
  );

  insert into public.app_users (id, name, email, role, status, pin_hash, data, depot_id)
  values (
    v_uid,
    coalesce(p_name, ''),
    lower(trim(p_email)),
    'superadmin',
    'active',
    crypt(p_pin, gen_salt('bf')),
    '{}'::jsonb,
    null
  );

  insert into public.sync_documents (collection, id, data, version, updated_at, depot_id)
  values (
    'users',
    v_uid::text,
    jsonb_build_object(
      'id',        v_uid::text,
      'name',      coalesce(p_name, ''),
      'email',     lower(trim(p_email)),
      'phone',     '',
      'role',      'superadmin',
      'status',    'active',
      'createdAt', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    ),
    1,
    now(),
    null
  )
  on conflict (collection, id) do update
    set data       = excluded.data,
        version    = public.sync_documents.version + 1,
        updated_at = now();

  return jsonb_build_object(
    'id',     v_uid,
    'email',  lower(trim(p_email)),
    'secret', v_secret
  );
end;
$$;

revoke all on function public.admin_bootstrap(text, text, text) from public;
grant execute on function public.admin_bootstrap(text, text, text) to anon;