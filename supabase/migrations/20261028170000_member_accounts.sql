-- Upendo Pamoja member data for the join, profile, and settings screens.
--
-- Accounts: email, password hash, and Google sign-in live in auth.users and
-- auth.identities. This migration does not copy passwords or create a second
-- user table.
--
-- Date of birth stays in private_identity. Optional HIV status stays in
-- health_profiles. Neither is a discovery column.
-- Location is a country, region, city, or broad area. distance_km is cleared
-- on write and is not a GPS radius.
-- "I'm a" and "I'm looking for" are not stored, so they cannot hide people.
-- A one-way favorite or like is not readable by the other person.

alter table public.profiles
  add column member_code text,
  add column home_country text,
  add column home_region text,
  add column home_area text,
  add column pref_country text,
  add column pref_region text,
  add column pref_city text,
  add column connection_reach text not null default 'This city',
  add column relationship_intents text[] not null default '{}',
  add column marital_status text,
  add column what_matters text,
  add column how_to_meet text,
  add column presence text not null default 'online';

comment on column public.profiles.member_code is
  'Display reference only. Not a clinic number, patient number, or medical-record number.';

comment on column public.profiles.city is
  'City or broad area shown on a profile. Never a street address or GPS point.';

comment on column public.profiles.connection_reach is
  'How widely someone is open to connecting. Not a kilometre radius and not a phone location.';

comment on column public.profiles.distance_km is
  'Unused. Precise distance is not collected. Writes are cleared.';

alter table public.profiles
  drop constraint if exists profiles_connection_reach_known,
  add constraint profiles_connection_reach_known check (connection_reach in (
    'This area',
    'This city',
    'Anywhere in Kenya',
    'Anywhere in this country',
    'Neighbouring countries'
  )),
  drop constraint if exists profiles_relationship_intents_known,
  add constraint profiles_relationship_intents_known check (
    relationship_intents <@ array[
      'marriage', 'long_term', 'companionship', 'friendship', 'unsure'
    ]::text[]
  ),
  drop constraint if exists profiles_marital_status_known,
  add constraint profiles_marital_status_known check (marital_status is null or marital_status in (
    'Single', 'Separated', 'Widowed', 'Divorced', 'Prefer not to say'
  )),
  drop constraint if exists profiles_what_matters_known,
  add constraint profiles_what_matters_known check (what_matters is null or what_matters in (
    'Kindness', 'Honesty', 'Shared faith', 'Family', 'Everyday companionship', 'Prefer not to say'
  )),
  drop constraint if exists profiles_how_to_meet_known,
  add constraint profiles_how_to_meet_known check (how_to_meet is null or how_to_meet in (
    'Messages first', 'Take time before meeting', 'Meet when it feels safe', 'Prefer not to say'
  )),
  drop constraint if exists profiles_presence_known,
  add constraint profiles_presence_known check (presence in ('online', 'busy'));

create or replace function private.assign_member_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate text;
  tries integer := 0;
begin
  if new.member_code is not null then
    return new;
  end if;
  loop
    tries := tries + 1;
    candidate := lpad((floor(random() * 900000) + 100000)::integer::text, 6, '0');
    exit when not exists (select 1 from public.profiles where member_code = candidate);
    if tries > 30 then
      raise exception 'Could not assign a member code';
    end if;
  end loop;
  new.member_code := candidate;
  return new;
end;
$$;

drop trigger if exists profiles_member_code on public.profiles;
create trigger profiles_member_code
  before insert on public.profiles
  for each row execute function private.assign_member_code();

do $$
declare
  member record;
  candidate text;
  tries integer;
begin
  for member in select user_id from public.profiles where member_code is null loop
    tries := 0;
    loop
      tries := tries + 1;
      candidate := lpad((floor(random() * 900000) + 100000)::integer::text, 6, '0');
      exit when not exists (select 1 from public.profiles where member_code = candidate);
      if tries > 30 then
        raise exception 'Could not assign a member code';
      end if;
    end loop;
    update public.profiles set member_code = candidate where user_id = member.user_id;
  end loop;
end $$;

alter table public.profiles alter column member_code set not null;
create unique index if not exists profiles_member_code_idx on public.profiles (member_code);

create or replace function private.clear_unused_distance()
returns trigger
language plpgsql
as $$
begin
  new.distance_km = null;
  return new;
end;
$$;

drop trigger if exists profiles_clear_distance on public.profiles;
create trigger profiles_clear_distance
  before insert or update on public.profiles
  for each row execute function private.clear_unused_distance();

create table public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email_messages boolean not null default true,
  email_match boolean not null default true,
  email_reply boolean not null default true,
  mobile_messages boolean not null default true,
  mobile_match boolean not null default true,
  realtime_messages boolean not null default true,
  updated_at timestamptz not null default now()
);

comment on table public.notification_preferences is
  'Owner-only alerts for messages and mutual matches. No promotion list, and no alert that reveals a one-way like or health information.';

create trigger notification_preferences_touch
  before update on public.notification_preferences
  for each row execute function private.touch_updated_at();

create or replace function private.create_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.create_notification_preferences();

insert into public.notification_preferences (user_id)
select id from auth.users
on conflict (user_id) do nothing;

create table public.favorites (
  owner_id uuid not null references auth.users (id) on delete cascade,
  favorite_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, favorite_id),
  check (owner_id <> favorite_id)
);

comment on table public.favorites is
  'A private note. A one-way favorite is visible only to the person who saved it. Mutual favorites are visible to both. A favorite is not a match.';

create index favorites_favorite_idx on public.favorites (favorite_id);

create or replace function private.favorites_are_mutual(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.favorites where owner_id = a and favorite_id = b
  ) and exists (
    select 1 from public.favorites where owner_id = b and favorite_id = a
  );
$$;

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
  age_years integer
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
    extract(year from age(current_date, i.date_of_birth))::integer as age_years
  from public.profiles p
  join public.private_identity i on i.user_id = p.user_id
  join public.profiles me on me.user_id = auth.uid()
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id)
    and extract(year from age(current_date, i.date_of_birth))::integer
        between me.age_preference_min and me.age_preference_max
    and (
      me.connection_reach not in ('This area', 'This city')
      or me.pref_city is null
      or p.city ilike '%' || me.pref_city || '%'
    )
    and (
      me.connection_reach is distinct from 'Anywhere in Kenya'
      or coalesce(p.home_country, 'Kenya') = 'Kenya'
    );
$$;

comment on function public.discovery_cards() is
  'Suggestions from stated age and place preferences. Returns age, never a date of birth, HIV status, street address, or GPS point.';

revoke all on function public.discovery_cards() from public, anon;
grant execute on function public.discovery_cards() to authenticated;

revoke all on function private.assign_member_code() from public;
revoke all on function private.clear_unused_distance() from public;
revoke all on function private.create_notification_preferences() from public;
revoke all on function private.favorites_are_mutual(uuid, uuid) from public;
grant execute on function private.favorites_are_mutual(uuid, uuid) to authenticated;

alter table public.notification_preferences enable row level security;
alter table public.favorites enable row level security;
alter table public.notification_preferences force row level security;
alter table public.favorites force row level security;

create policy notification_preferences_owner on public.notification_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy favorites_insert on public.favorites
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and not private.pair_is_blocked(auth.uid(), favorite_id)
  );

create policy favorites_delete on public.favorites
  for delete to authenticated
  using (owner_id = auth.uid());

create policy favorites_read on public.favorites
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (
      favorite_id = auth.uid()
      and private.favorites_are_mutual(auth.uid(), owner_id)
    )
  );

drop policy if exists photos_match_read on public.profile_photos;
create policy photos_match_read on public.profile_photos
  for select to authenticated
  using (
    exists (
      select 1
      from public.matches m
      where m.unmatched_at is null
        and auth.uid() in (m.user_a, m.user_b)
        and profile_photos.user_id in (m.user_a, m.user_b)
        and not private.pair_is_blocked(m.user_a, m.user_b)
    )
  );

revoke all on public.notification_preferences from anon;
revoke all on public.favorites from anon;
grant select, insert, update on public.notification_preferences to authenticated;
grant select, insert, delete on public.favorites to authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    execute $policy$
      drop policy if exists profile_photos_match_read on storage.objects;
      create policy profile_photos_match_read on storage.objects
        for select to authenticated
        using (
          bucket_id = 'profile-photos'
          and exists (
            select 1
            from public.matches m
            where m.unmatched_at is null
              and auth.uid() in (m.user_a, m.user_b)
              and (storage.foldername(name))[1] in (m.user_a::text, m.user_b::text)
              and not private.pair_is_blocked(m.user_a, m.user_b)
          )
        );
    $policy$;
  end if;
end $$;
