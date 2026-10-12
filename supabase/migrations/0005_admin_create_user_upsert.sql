-- Depot Distribution — fix admin_create_user's auth.users upsert
--
-- Run after 0003 (and 0004). Safe to re-run.
--
-- `admin_create_user` created (or reused) the Supabase auth user with:
--
--     insert into auth.users (...) ... on conflict (email) do update ...
--
-- In current Supabase, `auth.users.email` is only covered by a PARTIAL unique
-- index (`users_email_partial_key`, `WHERE is_sso_user = false`). A bare
-- `on conflict (email)` cannot infer a partial index, so every account creation
-- failed with:
--
--     42P10: there is no unique or exclusion constraint matching the
--            ON CONFLICT specification
--
-- This redefines the function to upsert the auth user explicitly: attempt the
-- insert with an arbiter-less `on conflict do nothing` (which matches any unique
-- violation, partial index included), then, when an account with that email
-- already existed, reuse it and refresh its password / metadata. The rest of the
-- function is unchanged from the 0003 definition.

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

  -- Create the auth user, or reuse the existing account with that email.
  -- Arbiter-less `on conflict do nothing` avoids the unusable
  -- `on conflict (email)` inference; a skipped insert leaves v_uid null.
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
  on conflict do nothing
  returning id into v_uid;

  if v_uid is null then
    select u.id into v_uid
      from auth.users u
     where u.email = lower(trim(p_email));

    update auth.users
       set encrypted_password = crypt(v_secret, gen_salt('bf')),
           aud                = 'authenticated',
           role               = 'authenticated',
           raw_app_meta_data  = '{"provider":"email","providers":["email"]}'::jsonb,
           email_confirmed_at = coalesce(email_confirmed_at, now()),
           updated_at         = now()
     where id = v_uid;
  end if;

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
