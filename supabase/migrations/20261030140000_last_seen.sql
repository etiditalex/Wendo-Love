-- Online means the member's app is open. Last seen is the time they left.
-- This is not a location, and it is not a health field.

alter table public.profiles
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen_at timestamptz;

comment on column public.profiles.is_online is
  'True while this member has the app open. Cleared when they leave or sign out.';

comment on column public.profiles.last_seen_at is
  'When this member last had the app open. Shown as Online, or as a relative time such as 39 minutes ago.';

drop function if exists public.discovery_cards();

create function public.discovery_cards()
returns table (
  user_id uuid,
  display_name text,
  member_code text,
  city text,
  bio text,
  languages text[],
  interests text[],
  relationship_intent text,
  relationship_intents text[],
  family_goals text,
  children_preference text,
  what_matters text,
  how_to_meet text,
  presence text,
  age_years integer,
  photo_path text,
  is_online boolean,
  last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.display_name,
    p.member_code,
    p.city,
    p.bio,
    p.languages,
    p.interests,
    p.relationship_intent,
    p.relationship_intents,
    p.family_goals,
    p.children_preference,
    p.what_matters,
    p.how_to_meet,
    p.presence,
    extract(year from age(current_date, i.date_of_birth))::integer as age_years,
    (
      select ph.storage_path
      from public.profile_photos ph
      where ph.user_id = p.user_id
      order by ph.sort_order, ph.created_at
      limit 1
    ) as photo_path,
    p.is_online,
    p.last_seen_at
  from public.profiles p
  left join public.private_identity i on i.user_id = p.user_id
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id);
$$;

comment on function public.discovery_cards() is
  'Finished profiles for Home. Returns age, a private photo path, and last seen. Never a date of birth, HIV status, street address, or GPS point.';

revoke all on function public.discovery_cards() from public, anon;
grant execute on function public.discovery_cards() to authenticated;
