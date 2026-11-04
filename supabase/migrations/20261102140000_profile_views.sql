-- Who opened your profile. This is not a location, health, or clinic record.

create table if not exists public.profile_views (
  viewer_id uuid not null references auth.users (id) on delete cascade,
  viewed_id uuid not null references auth.users (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (viewer_id, viewed_id),
  check (viewer_id <> viewed_id)
);

create index if not exists profile_views_viewed_idx on public.profile_views (viewed_id, viewed_at desc);

comment on table public.profile_views is
  'A signed-in member opened another finished profile. Never stores HIV status, date of birth, a street address, or GPS.';

alter table public.profile_views enable row level security;
alter table public.profile_views force row level security;

drop policy if exists views_insert_own on public.profile_views;
create policy views_insert_own on public.profile_views
  for insert to authenticated
  with check (viewer_id = auth.uid() and viewed_id <> auth.uid());

drop policy if exists views_update_own on public.profile_views;
create policy views_update_own on public.profile_views
  for update to authenticated
  using (viewer_id = auth.uid())
  with check (viewer_id = auth.uid());

drop policy if exists views_read_own on public.profile_views;
create policy views_read_own on public.profile_views
  for select to authenticated
  using (viewed_id = auth.uid() or viewer_id = auth.uid());

grant select, insert, update on public.profile_views to authenticated;

create or replace function public.record_profile_view(other_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to open a profile';
  end if;
  if other_user is null or other_user = auth.uid() then
    return;
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.user_id = other_user
      and p.onboarding_completed = true
      and p.account_paused = false
  ) then
    return;
  end if;
  if private.pair_is_blocked(auth.uid(), other_user) then
    return;
  end if;

  insert into public.profile_views (viewer_id, viewed_id, viewed_at)
  values (auth.uid(), other_user, now())
  on conflict (viewer_id, viewed_id) do update
    set viewed_at = excluded.viewed_at;
end;
$$;

comment on function public.record_profile_view(uuid) is
  'Records that the signed-in member opened another profile. Does not store health or location detail.';

revoke all on function public.record_profile_view(uuid) from public, anon;
grant execute on function public.record_profile_view(uuid) to authenticated;

create or replace function public.list_profile_viewers()
returns table (
  user_id uuid,
  display_name text,
  city text,
  viewed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.display_name,
    p.city,
    v.viewed_at
  from public.profile_views v
  join public.profiles p on p.user_id = v.viewer_id
  where auth.uid() is not null
    and v.viewed_id = auth.uid()
    and p.onboarding_completed = true
    and p.account_paused = false
    and not private.pair_is_blocked(auth.uid(), p.user_id)
  order by v.viewed_at desc;
$$;

comment on function public.list_profile_viewers() is
  'People who opened your profile, newest first. Returns a name and city only.';

revoke all on function public.list_profile_viewers() from public, anon;
grant execute on function public.list_profile_viewers() to authenticated;

create or replace function public.list_viewed_profiles()
returns table (
  user_id uuid,
  display_name text,
  city text,
  viewed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.display_name,
    p.city,
    v.viewed_at
  from public.profile_views v
  join public.profiles p on p.user_id = v.viewed_id
  where auth.uid() is not null
    and v.viewer_id = auth.uid()
    and p.onboarding_completed = true
    and p.account_paused = false
    and not private.pair_is_blocked(auth.uid(), p.user_id)
  order by v.viewed_at desc;
$$;

comment on function public.list_viewed_profiles() is
  'Profiles the signed-in member opened, newest first. Returns a name and city only.';

revoke all on function public.list_viewed_profiles() from public, anon;
grant execute on function public.list_viewed_profiles() to authenticated;
