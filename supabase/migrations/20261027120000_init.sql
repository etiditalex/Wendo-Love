-- Upendo Pamoja
-- Identity and optional health data are separate.
-- HIV status is optional, private by default, and never inferred.
-- Do not add clinic names, ART cards, medical-record numbers, patient numbers, or viral load.

create schema if not exists private;

revoke all on schema private from public, anon;
grant usage on schema private to postgres, service_role, authenticated;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.enforce_adult()
returns trigger
language plpgsql
as $$
begin
  if new.date_of_birth > (current_date - interval '18 years')::date then
    raise exception 'Members must be 18 or older';
  end if;
  return new;
end;
$$;

create table public.private_identity (
  user_id uuid primary key references auth.users (id) on delete cascade,
  date_of_birth date not null,
  country_code text not null default 'KE',
  created_at timestamptz not null default now()
);

comment on table public.private_identity is
  'Owner-only identity. Date of birth proves 18+ and is not copied onto discovery cards.';

create trigger private_identity_adult
  before insert or update on public.private_identity
  for each row execute function private.enforce_adult();

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 40),
  city text,
  bio text check (bio is null or char_length(bio) <= 600),
  languages text[] not null default '{}',
  occupation text,
  faith text,
  interests text[] not null default '{}',
  relationship_intent text not null check (relationship_intent in (
    'marriage', 'long_term', 'companionship', 'friendship', 'unsure'
  )),
  family_goals text,
  children_preference text,
  smoking_preference text,
  alcohol_preference text,
  age_preference_min integer not null default 18 check (age_preference_min >= 18),
  age_preference_max integer not null default 80 check (
    age_preference_max >= age_preference_min and age_preference_max <= 120
  ),
  distance_km integer check (distance_km is null or distance_km between 1 and 500),
  communication_boundaries text,
  account_paused boolean not null default false,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Member-facing profile. No HIV status, clinic, or precise location.';

create trigger profiles_touch
  before update on public.profiles
  for each row execute function private.touch_updated_at();

create table public.health_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  self_described_status text not null check (self_described_status in (
    'living_with_hiv', 'hiv_negative', 'prefer_not_to_say', 'not_sure'
  )),
  disclosure_preference text not null default 'never' check (disclosure_preference in (
    'never', 'when_i_choose'
  )),
  consent_version text not null,
  consented_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.health_profiles is
  'Optional self-described status. Owner-only. Never joined into discovery.';

create trigger health_profiles_touch
  before update on public.health_profiles
  for each row execute function private.touch_updated_at();

create table public.health_shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  status_shared text not null check (status_shared in (
    'living_with_hiv', 'hiv_negative', 'prefer_not_to_say', 'not_sure'
  )),
  shared_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (owner_id, recipient_id),
  check (owner_id <> recipient_id)
);

comment on table public.health_shares is
  'An explicit share with one mutual match. Not a live join to health_profiles.';

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  consent_type text not null check (consent_type in (
    'terms', 'privacy', 'community_rules', 'optional_health'
  )),
  version text not null,
  accepted_at timestamptz not null default now()
);

create table public.likes (
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user),
  check (from_user <> to_user)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unmatched_by uuid,
  unmatched_at timestamptz,
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table public.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create or replace function private.pair_is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_user_id uuid not null references auth.users (id) on delete cascade,
  reason text not null check (reason in (
    'harassment', 'scam', 'impersonation', 'outing_threat', 'coercion', 'spam', 'other'
  )),
  details text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now()
);

create table public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.trusted_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null,
  phone text not null,
  created_at timestamptz not null default now()
);

comment on table public.trusted_contacts is
  'Owner-only check-in contact for in-person meetings.';

create index likes_to_user_idx on public.likes (to_user);
create index messages_match_idx on public.messages (match_id, created_at);
create index reports_status_idx on public.reports (status);

create or replace function private.create_match_on_mutual_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.likes
    where from_user = new.to_user
      and to_user = new.from_user
  ) then
    insert into public.matches (user_a, user_b)
    values (least(new.from_user, new.to_user), greatest(new.from_user, new.to_user))
    on conflict (user_a, user_b) do nothing;
  end if;
  return new;
end;
$$;

create trigger likes_mutual_match
  after insert on public.likes
  for each row execute function private.create_match_on_mutual_like();

create or replace function private.guard_health_share()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recorded text;
  preference text;
begin
  if not exists (
    select 1
    from public.matches
    where unmatched_at is null
      and user_a = least(new.owner_id, new.recipient_id)
      and user_b = greatest(new.owner_id, new.recipient_id)
  ) then
    raise exception 'Status can only be shared with a mutual match';
  end if;

  select self_described_status, disclosure_preference
    into recorded, preference
  from public.health_profiles
  where user_id = new.owner_id;

  if preference is distinct from 'when_i_choose' then
    raise exception 'Sharing is turned off on this profile';
  end if;

  if new.status_shared is distinct from recorded then
    raise exception 'Shared status must match the status you saved';
  end if;

  return new;
end;
$$;

create trigger health_shares_guard
  before insert or update of status_shared, recipient_id on public.health_shares
  for each row execute function private.guard_health_share();

create or replace function public.discovery_cards()
returns table (
  user_id uuid,
  display_name text,
  city text,
  bio text,
  languages text[],
  interests text[],
  relationship_intent text,
  family_goals text,
  children_preference text,
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
    p.city,
    p.bio,
    p.languages,
    p.interests,
    p.relationship_intent,
    p.family_goals,
    p.children_preference,
    extract(year from age(current_date, i.date_of_birth))::integer as age_years
  from public.profiles p
  join public.private_identity i on i.user_id = p.user_id
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id);
$$;

comment on function public.discovery_cards() is
  'Preference cards for signed-in members. Returns age, never a date of birth or HIV status.';

revoke all on function public.discovery_cards() from public, anon;
grant execute on function public.discovery_cards() to authenticated;

revoke all on function private.touch_updated_at() from public;
revoke all on function private.enforce_adult() from public;
revoke all on function private.pair_is_blocked(uuid, uuid) from public;
revoke all on function private.create_match_on_mutual_like() from public;
revoke all on function private.guard_health_share() from public;
grant execute on function private.pair_is_blocked(uuid, uuid) to authenticated;

alter table public.private_identity enable row level security;
alter table public.profiles enable row level security;
alter table public.health_profiles enable row level security;
alter table public.health_shares enable row level security;
alter table public.consents enable row level security;
alter table public.likes enable row level security;
alter table public.matches enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.profile_photos enable row level security;
alter table public.trusted_contacts enable row level security;

alter table public.private_identity force row level security;
alter table public.profiles force row level security;
alter table public.health_profiles force row level security;
alter table public.health_shares force row level security;
alter table public.consents force row level security;
alter table public.likes force row level security;
alter table public.matches force row level security;
alter table public.messages force row level security;
alter table public.blocks force row level security;
alter table public.reports force row level security;
alter table public.profile_photos force row level security;
alter table public.trusted_contacts force row level security;

create policy private_identity_owner on public.private_identity
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy profiles_owner_write on public.profiles
  for insert to authenticated
  with check (user_id = auth.uid());

create policy profiles_owner_update on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy profiles_read on public.profiles
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      account_paused = false
      and onboarding_completed = true
      and not private.pair_is_blocked(auth.uid(), user_id)
    )
  );

create policy health_profiles_owner on public.health_profiles
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy health_shares_insert on public.health_shares
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy health_shares_update on public.health_shares
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy health_shares_read on public.health_shares
  for select to authenticated
  using (
    owner_id = auth.uid()
    or (recipient_id = auth.uid() and revoked_at is null)
  );

create policy consents_owner on public.consents
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy likes_insert on public.likes
  for insert to authenticated
  with check (
    from_user = auth.uid()
    and not private.pair_is_blocked(auth.uid(), to_user)
  );

create policy likes_read_outgoing on public.likes
  for select to authenticated
  using (from_user = auth.uid());

create policy likes_delete_own on public.likes
  for delete to authenticated
  using (from_user = auth.uid());

create policy matches_read on public.matches
  for select to authenticated
  using (
    auth.uid() in (user_a, user_b)
    and unmatched_at is null
    and not private.pair_is_blocked(user_a, user_b)
  );

create policy matches_unmatch on public.matches
  for update to authenticated
  using (auth.uid() in (user_a, user_b))
  with check (
    auth.uid() in (user_a, user_b)
    and unmatched_by = auth.uid()
  );

create policy messages_read on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.matches m
      where m.id = messages.match_id
        and m.unmatched_at is null
        and auth.uid() in (m.user_a, m.user_b)
        and not private.pair_is_blocked(m.user_a, m.user_b)
    )
  );

create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.matches m
      where m.id = match_id
        and m.unmatched_at is null
        and auth.uid() in (m.user_a, m.user_b)
        and not private.pair_is_blocked(m.user_a, m.user_b)
    )
  );

create policy blocks_owner on public.blocks
  for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

create policy reports_insert on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

create policy reports_read_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

create policy photos_owner on public.profile_photos
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy trusted_contacts_owner on public.trusted_contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on public.private_identity to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.health_profiles to authenticated;
grant select, insert, update on public.health_shares to authenticated;
grant select, insert on public.consents to authenticated;
grant select, insert, delete on public.likes to authenticated;
grant select on public.matches to authenticated;
grant update (unmatched_at, unmatched_by) on public.matches to authenticated;
grant select, insert on public.messages to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant select, insert on public.reports to authenticated;
grant select, insert, update, delete on public.profile_photos to authenticated;
grant select, insert, update, delete on public.trusted_contacts to authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public)
    values ('profile-photos', 'profile-photos', false)
    on conflict (id) do update set public = false;

    execute $policy$
      drop policy if exists profile_photos_owner_read on storage.objects;
      create policy profile_photos_owner_read on storage.objects
        for select to authenticated
        using (
          bucket_id = 'profile-photos'
          and (storage.foldername(name))[1] = auth.uid()::text
        );
      drop policy if exists profile_photos_owner_write on storage.objects;
      create policy profile_photos_owner_write on storage.objects
        for insert to authenticated
        with check (
          bucket_id = 'profile-photos'
          and (storage.foldername(name))[1] = auth.uid()::text
        );
      drop policy if exists profile_photos_owner_delete on storage.objects;
      create policy profile_photos_owner_delete on storage.objects
        for delete to authenticated
        using (
          bucket_id = 'profile-photos'
          and (storage.foldername(name))[1] = auth.uid()::text
        );
    $policy$;
  end if;

  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
