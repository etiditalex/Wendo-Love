-- Pass/skip, photo-verified badge, and discovery that hides passed people.
-- Passes are private. They are not a ranking signal and never include health data.
-- photo_verified_at means the member completed a confirmation photo. It is not a health badge.

create table if not exists public.passes (
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user),
  check (from_user <> to_user)
);

comment on table public.passes is
  'Private pass/skip. Hides a profile from the passer''s Home feed. Never shared with the other person.';

alter table public.passes enable row level security;
alter table public.passes force row level security;

drop policy if exists passes_owner on public.passes;
create policy passes_owner on public.passes
  for all to authenticated
  using (from_user = auth.uid())
  with check (from_user = auth.uid());

grant select, insert, delete on public.passes to authenticated;

alter table public.profiles
  add column if not exists photo_verified_at timestamptz;

comment on column public.profiles.photo_verified_at is
  'When this member completed a confirmation photo check. Not a health badge and not a ranking flag.';

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
  last_seen_at timestamptz,
  photo_verified boolean
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
    p.last_seen_at,
    (p.photo_verified_at is not null) as photo_verified
  from public.profiles p
  left join public.private_identity i on i.user_id = p.user_id
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id)
    and not exists (
      select 1
      from public.passes s
      where s.from_user = auth.uid()
        and s.to_user = p.user_id
    );
$$;

comment on function public.discovery_cards() is
  'Finished profiles for Home. Skips people you passed. Returns age and a private photo path, never DOB, HIV status, street address, or GPS.';

revoke all on function public.discovery_cards() from public, anon;
grant execute on function public.discovery_cards() to authenticated;
