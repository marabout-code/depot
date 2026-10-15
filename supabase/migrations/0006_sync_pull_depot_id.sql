-- ---------------------------------------------------------------------------
-- 0006_sync_pull_depot_id
--
-- The client now stores each synced row's owning depot in a local `depot_id`
-- column so it can filter reads on-device (and purge rows when the signed-in
-- depot changes). Previously the pull payload carried no depot, so the client
-- had no way to enforce the same scoping locally that RLS already enforces on
-- the server.
--
-- This is a pure add: the row shape gains a `depotId` (nullable, matching the
-- shared legacy rows) and every authorization rule from 0003 is preserved.
-- Depends on 0003 (is_unrestricted / depot_of_user / sync_documents).
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
               'updatedAt', d.updated_at,
               'depotId',   d.depot_id
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
             'updatedAt', d.updated_at,
             'depotId',   d.depot_id
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
