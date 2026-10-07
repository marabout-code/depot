-- Depot Distribution — Supabase schema (offline-first)
--
-- Run this once in the Supabase SQL editor, or with `supabase db push`.
--
-- The device database (SQLite via Drift) is the source of truth; Postgres here
-- is a sync peer, not a read path. That shapes the schema:
--
--   * One `sync_documents` table keyed by (collection, id) holds every synced
--     document as jsonb. A generic store is what lets one sync engine handle
--     all seven collections, and it mirrors the local Drift `documents` table
--     exactly, so reconciliation is a straight comparison.
--   * `version` is a monotonic per-row counter. Last-write-wins compares it,
--     with the row's `updated_at` as tiebreaker. Deliberately not a CRDT: a
--     half-merged order is worse than a clean last-writer-wins, and depot edits
--     are rarely simultaneous.
--   * PINs are never readable by the client. `app_users.pin_hash` is a pgcrypto
--     bcrypt hash compared inside `login_with_pin()`.
--   * Driver PIN hashes for offline verification never come from the server at
--     all; each device hashes the PIN it was given locally. See
--     `LocalAuthService` on the Dart side.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Sync tables
-- ---------------------------------------------------------------------------

create table if not exists public.sync_documents (
  collection    text        not null,
  id            text        not null,
  data          jsonb       not null default '{}'::jsonb,
  version       integer     not null default 1,
  deleted       boolean     not null default false,
  updated_at    timestamptz not null default now(),
  pushed_by     uuid,
  primary key (collection, id)
);

create index if not exists sync_documents_updated_at_idx
  on public.sync_documents (collection, updated_at desc);

-- ---------------------------------------------------------------------------
-- Users (auth profiles + PIN credentials)
-- ---------------------------------------------------------------------------

create table if not exists public.app_users (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text        not null default '',
  email       text        not null default '',
  phone       text        not null default '',
  role        text        not null default 'driver' check (role in ('admin', 'driver')),
  status      text        not null default 'active',
  pin_hash    text,
  data        jsonb       not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists app_users_role_idx on public.app_users (role);
create unique index if not exists app_users_pin_idx
  on public.app_users (pin_hash) where pin_hash is not null;

-- The Dart bcrypt hash used for offline verification on other devices. It is
-- deliberately *not* the pgcrypto hash: the two implementations are not
-- guaranteed to be wire-compatible, so each role keeps its own. Storing it here
-- is the trade-off chosen for multi-device offline login: any depot device can
-- verify a PIN without connectivity, at the cost of the hash being readable by
-- depot staff (mitigated by the bcrypt work factor and RLS).
alter table public.app_users
  add column if not exists pin_offline_hash text;

alter table public.app_users enable row level security;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = auth.uid() and u.role = 'admin' and u.status = 'active'
  );
$$;

-- Depot staff share one dataset, so synced documents are visible to any
-- authenticated depot user. Writes go exclusively through the RPCs below,
-- which enforce the version rule in one place.
alter table public.sync_documents enable row level security;

drop policy if exists sync_documents_read on public.sync_documents;
create policy sync_documents_read on public.sync_documents
  for select to authenticated
  using (exists (select 1 from public.app_users u where u.id = auth.uid()));

-- Direct writes are denied; sync_push_rows is security definer and validates
-- the caller itself.
drop policy if exists sync_documents_insert on public.sync_documents;
drop policy if exists sync_documents_update on public.sync_documents;
drop policy if exists sync_documents_delete on public.sync_documents;

drop policy if exists app_users_select on public.app_users;
create policy app_users_select on public.app_users
  for select to authenticated
  using (public.is_admin() or id = auth.uid());

drop policy if exists app_users_admin_write on public.app_users;
create policy app_users_admin_write on public.app_users
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- A driver may update their own profile, but never their own role: the policy
-- pins `role` and `pin_hash` to their current values.
drop policy if exists app_users_self_update on public.app_users;
create policy app_users_self_update on public.app_users
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = (select u.role from public.app_users u where u.id = auth.uid())
    and pin_hash is not distinct from (select u.pin_hash from public.app_users u where u.id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Sync RPCs
-- ---------------------------------------------------------------------------

-- Accepts a batch of locally changed rows for one collection and returns the
-- rows the server accepted. A row is accepted only when its version beats what
-- is already stored; ties break on updated_at, so the losing device's write is
-- simply not applied and its next pull brings the winner back down.
create or replace function public.sync_push_rows(
  p_collection text,
  p_rows       jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row       jsonb;
  v_accepted  jsonb := '[]'::jsonb;
begin
  if not exists (select 1 from public.app_users u where u.id = auth.uid()) then
    raise exception 'not_a_depot_user' using errcode = '42501';
  end if;

  if p_collection not in (
    'users', 'products', 'orders', 'deliveries',
    'inventory', 'movements', 'categories'
  ) then
    raise exception 'unknown_collection' using errcode = '42501';
  end if;

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
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
      coalesce(v_row -> 'data', '{}'::jsonb),
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

-- Returns rows changed since p_since so a device can catch up incrementally.
-- The null timestamp on first sync means "send me everything".
create or replace function public.sync_pull_rows(
  p_collection text,
  p_since      timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.app_users u where u.id = auth.uid()) then
    raise exception 'not_a_depot_user' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id',        d.id,
             'data',      d.data,
             'version',   d.version,
             'deleted',   d.deleted,
             'updatedAt', d.updated_at
           ))
    from public.sync_documents d
    where d.collection = p_collection
      and (p_since is null or d.updated_at > p_since)
    order by d.updated_at
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.sync_pull_rows(text, timestamptz) from public;
grant execute on function public.sync_pull_rows(text, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- PIN login
-- ---------------------------------------------------------------------------

create or replace function public.verify_pin(p_pin text, p_hash text)
returns boolean
language sql
immutable
as $$
  select p_hash is not null
     and p_pin is not null
     and crypt(p_pin, p_hash) = p_hash;
$$;

create table if not exists public.pin_login_attempts (
  key             text primary key,
  failures        integer     not null default 0,
  last_attempt_at timestamptz not null default now()
);

alter table public.pin_login_attempts enable row level security;

-- A 4 digit PIN is only 1e4 candidates, so online PIN login is throttled
-- independently of the on-device lockout.
create or replace function public.pin_login_allowed(p_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_failures integer;
begin
  -- Sum the failures, not the rows: there is one row per key, so counting rows
  -- would always be 1 and the throttle would never engage.
  select coalesce(sum(failures), 0) into v_failures
  from public.pin_login_attempts
  where key = p_key
    and last_attempt_at > now() - interval '15 minutes';

  return v_failures < 5;
end;
$$;

-- Compares the PIN against every active hash, then mints a Supabase session by
-- setting a fresh random password and handing the secret back for GoTrue's
-- normal password grant. The PIN itself is never returned or logged, and only
-- its bcrypt hash is ever stored.
create or replace function public.login_with_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user       public.app_users%rowtype;
  v_secret     text;
  v_auth_row   jsonb;
  v_attempt_key text := coalesce(p_pin, 'null');
begin
  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  if not public.pin_login_allowed(v_attempt_key) then
    raise exception 'too_many_attempts' using errcode = 'P0001';
  end if;

  select * into v_user
  from public.app_users
  where public.verify_pin(p_pin, pin_hash)
    and status = 'active'
  limit 1;

  if not found then
    insert into public.pin_login_attempts (key, failures, last_attempt_at)
    values (v_attempt_key, 1, now())
    on conflict (key) do update
      set failures = public.pin_login_attempts.failures + 1,
          last_attempt_at = now();

    raise exception 'invalid_pin' using errcode = 'P0001';
  end if;

  delete from public.pin_login_attempts where key = v_attempt_key;

  v_secret := encode(gen_random_bytes(32), 'hex');

  update auth.users
     set encrypted_password = crypt(v_secret, gen_salt('bf')),
         updated_at = now()
   where id = v_user.id
  returning to_jsonb(auth.users.*) into v_auth_row;

  return jsonb_build_object(
    'user_id', v_user.id,
    'email',   v_auth_row ->> 'email',
    'secret',  v_secret
  );
end;
$$;

revoke all on function public.login_with_pin(text) from public;
grant execute on function public.login_with_pin(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin account management
-- ---------------------------------------------------------------------------

-- Creates a depot account with a hashed PIN. Returns the generated session
-- secret so the creating device can sign in immediately.
create or replace function public.admin_create_user(
  p_email            text,
  p_name             text,
  p_pin              text,
  p_role             text default 'driver',
  p_phone            text default '',
  p_data             jsonb default '{}'::jsonb,
  p_offline_pin_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid;
  v_user_id uuid := gen_random_uuid();
  v_secret  text := encode(gen_random_bytes(32), 'hex');
begin
  if not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  insert into auth.users (id, instance_id, email, encrypted_password, email_confirmed_at)
  values (
    v_user_id,
    -- Standard GoTrue instance id; `select ... from auth.users limit 1` is null
    -- on a brand-new project, so hardcode it.
    '00000000-0000-0000-0000-000000000000'::uuid,
    lower(trim(p_email)),
    crypt(v_secret, gen_salt('bf')),
    now()
  )
  on conflict (email) do update
    set encrypted_password = excluded.encrypted_password
  returning id into v_uid;

  insert into public.app_users (id, name, email, phone, role, status, pin_hash, pin_offline_hash, data)
  values (
    v_uid,
    coalesce(p_name, ''),
    lower(trim(p_email)),
    coalesce(p_phone, ''),
    coalesce(p_role, 'driver'),
    'active',
    crypt(p_pin, gen_salt('bf')),
    coalesce(p_offline_pin_hash, null),
    coalesce(p_data, '{}'::jsonb)
  )
  on conflict (id) do update
    set name            = excluded.name,
        phone           = excluded.phone,
        role            = excluded.role,
        pin_hash        = excluded.pin_hash,
        pin_offline_hash = excluded.pin_offline_hash,
        data            = excluded.data,
        updated_at      = now();

  return jsonb_build_object(
    'id',     v_uid,
    'email',  lower(trim(p_email)),
    'secret', v_secret
  );
end;
$$;

revoke all on function public.admin_create_user(text, text, text, text, text, jsonb, text) from public;
grant execute on function public.admin_create_user(text, text, text, text, text, jsonb, text) to authenticated;

-- Rotates a PIN. The caller's own hash never leaves the database; the Dart
-- hash for offline use is stored alongside it, unverified by pgcrypto.
create or replace function public.admin_set_pin(
  p_user_id          uuid,
  p_pin              text,
  p_offline_pin_hash text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
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

-- Publishes a profile row into the synced dataset so other devices can see the
-- new user without a separate pull path.
create or replace function public.app_users_sync_upsert(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.app_users%rowtype;
begin
  -- Only an admin, or the user publishing their own profile, may write here.
  if not (public.is_admin() or p_user_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_row from public.app_users where id = p_user_id;

  if not found then
    raise exception 'row_not_found' using errcode = 'P0002';
  end if;

  insert into public.sync_documents (collection, id, data, version, updated_at, pushed_by)
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
      'createdAt',      to_char(v_row.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'updatedAt',      to_char(v_row.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
    )),
    1,
    now(),
    auth.uid()
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
-- Signature photos
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('signatures', 'signatures', false)
on conflict (id) do nothing;

drop policy if exists signatures_read on storage.objects;
create policy signatures_read on storage.objects
  for select to authenticated
  using (bucket_id = 'signatures');

drop policy if exists signatures_write on storage.objects;
create policy signatures_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'signatures');

-- ---------------------------------------------------------------------------
-- First admin bootstrap
-- ---------------------------------------------------------------------------

-- Refuses to run once any admin exists, so it cannot be used to escalate
-- privileges later. Change the email and PIN before real use.
create or replace function public.admin_bootstrap(
  p_email text,
  p_name  text,
  p_pin   text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := gen_random_uuid();
  v_secret  text := encode(gen_random_bytes(32), 'hex');
begin
  if exists (select 1 from public.app_users where role = 'admin') then
    raise exception 'admin_already_exists' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^[0-9]{4}$' then
    raise exception 'invalid_pin_format' using errcode = '22023';
  end if;

  insert into auth.users (id, instance_id, email, encrypted_password, email_confirmed_at)
  values (
    v_uid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    lower(trim(p_email)),
    crypt(v_secret, gen_salt('bf')),
    now()
  );

  insert into public.app_users (id, name, email, role, status, pin_hash, data)
  values (
    v_uid,
    coalesce(p_name, ''),
    lower(trim(p_email)),
    'admin',
    'active',
    crypt(p_pin, gen_salt('bf')),
    '{}'::jsonb
  );

  return jsonb_build_object(
    'id',     v_uid,
    'email',  lower(trim(p_email)),
    'secret', v_secret
  );
end;
$$;

revoke all on function public.admin_bootstrap(text, text, text) from public;

-- The first run is done in the app (online), so an anonymous caller may invoke
-- it exactly once: the function refuses to run once any admin exists.
grant execute on function public.admin_bootstrap(text, text, text) to anon;

-- Run once in the SQL editor instead if you prefer a manual bootstrap:
--   select public.admin_bootstrap('admin@depot.local', 'Depot Admin', '1234');