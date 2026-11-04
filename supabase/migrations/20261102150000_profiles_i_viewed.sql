-- Profiles this member opened. Same privacy rules as incoming views.

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
