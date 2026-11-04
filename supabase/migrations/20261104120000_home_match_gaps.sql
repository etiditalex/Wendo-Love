-- Optional self-described gender for the match card "seeking" line.
-- Not a clinic field, and not used as a hidden rank.

alter table public.profiles
  add column if not exists gender text,
  add column if not exists seeking_genders text[] not null default '{}',
  add column if not exists education text;

comment on column public.profiles.gender is
  'Optional self-described gender shown on the member''s own card. Never a health field.';
comment on column public.profiles.seeking_genders is
  'Who this member hopes to meet. Shown as the seeking line with their age range.';
comment on column public.profiles.education is
  'Optional self-described education. Used only when the member opens Wendo Plus filters.';

-- Counts for Popular and the photo chip. Does not reveal who liked whom.
create or replace function public.discovery_card_stats()
returns table (
  user_id uuid,
  photo_count integer,
  like_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    (select count(*)::integer from public.profile_photos ph where ph.user_id = p.user_id),
    (select count(*)::integer from public.likes l where l.to_user = p.user_id)
  from public.profiles p
  where p.onboarding_completed = true
    and p.account_paused = false
    and p.user_id is distinct from auth.uid();
$$;

revoke all on function public.discovery_card_stats() from public, anon;
grant execute on function public.discovery_card_stats() to authenticated;
