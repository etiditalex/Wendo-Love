-- Pilot gap fill: push tokens, check-ins, partners, premium interest, staff moderation, verify queue.

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.device_push_tokens enable row level security;
alter table public.device_push_tokens force row level security;

drop policy if exists push_tokens_own on public.device_push_tokens;
create policy push_tokens_own on public.device_push_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.device_push_tokens to authenticated;

create table if not exists public.meeting_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  match_id uuid references public.matches (id) on delete set null,
  other_user_id uuid references auth.users (id) on delete set null,
  place_note text,
  planned_at timestamptz,
  status text not null default 'planned'
    check (status in ('planned', 'started', 'safe', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.meeting_checkins enable row level security;
alter table public.meeting_checkins force row level security;

drop policy if exists checkins_own on public.meeting_checkins;
create policy checkins_own on public.meeting_checkins
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.meeting_checkins to authenticated;

alter table public.trusted_contacts enable row level security;
alter table public.trusted_contacts force row level security;

drop policy if exists trusted_contacts_own on public.trusted_contacts;
create policy trusted_contacts_own on public.trusted_contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.trusted_contacts to authenticated;

create table if not exists public.partner_resources (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('counseling', 'event', 'safety', 'learn')),
  title text not null,
  summary text not null,
  url text,
  region text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.partner_resources enable row level security;
alter table public.partner_resources force row level security;

drop policy if exists partner_resources_read on public.partner_resources;
create policy partner_resources_read on public.partner_resources
  for select to authenticated
  using (active = true);

grant select on public.partner_resources to authenticated;

insert into public.partner_resources (kind, title, summary, url, region, sort_order)
select * from (values
  ('counseling', 'Talk to a counselor', 'Confidential support for relationships and living with HIV. Partner links will open outside Wendo.', 'https://www.who.int/health-topics/hiv-aids', 'Kenya', 10),
  ('safety', 'Dating safety basics', 'Meet in public, tell a trusted person, and leave if you feel unsafe.', null, 'Kenya', 20),
  ('event', 'Community meetups', 'Moderated in-person events with vetted partners. Dates will appear here as they are confirmed.', null, 'Nairobi', 30),
  ('learn', 'Undetectable = Untransmittable', 'WHO: a person with an undetectable viral load does not transmit HIV sexually.', 'https://www.who.int/news-room/fact-sheets/detail/hiv-aids', null, 40)
) as v(kind, title, summary, url, region, sort_order)
where not exists (select 1 from public.partner_resources limit 1);

create table if not exists public.premium_interest (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null default 'wendo_plus',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.premium_interest enable row level security;
alter table public.premium_interest force row level security;

drop policy if exists premium_interest_own on public.premium_interest;
create policy premium_interest_own on public.premium_interest
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update on public.premium_interest to authenticated;

alter table public.profiles
  add column if not exists premium_until timestamptz,
  add column if not exists blur_until_mutual boolean not null default false,
  add column if not exists photo_verify_requested_at timestamptz,
  add column if not exists photo_verified_at timestamptz;

comment on column public.profiles.photo_verify_requested_at is
  'When this member uploaded a confirmation photo for staff review. Not a health badge.';

comment on column public.profiles.photo_verified_at is
  'When staff approved the confirmation photo. Not a health badge and not a ranking flag.';

create table if not exists public.staff_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('moderator', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.staff_roles enable row level security;
alter table public.staff_roles force row level security;

drop policy if exists staff_roles_read_own on public.staff_roles;
create policy staff_roles_read_own on public.staff_roles
  for select to authenticated
  using (user_id = auth.uid());

grant select on public.staff_roles to authenticated;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_roles s where s.user_id = auth.uid()
  );
$$;

revoke all on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;

drop policy if exists reports_staff_read on public.reports;
create policy reports_staff_read on public.reports
  for select to authenticated
  using (public.is_staff() or reporter_id = auth.uid());

drop policy if exists reports_staff_update on public.reports;
create policy reports_staff_update on public.reports
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

create or replace function public.moderation_queue()
returns table (
  id uuid,
  reporter_id uuid,
  reported_user_id uuid,
  reported_name text,
  reason text,
  details text,
  status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.reporter_id,
    r.reported_user_id,
    coalesce(p.display_name, 'Member') as reported_name,
    r.reason,
    r.details,
    r.status,
    r.created_at
  from public.reports r
  left join public.profiles p on p.user_id = r.reported_user_id
  where public.is_staff()
  order by r.created_at desc;
$$;

revoke all on function public.moderation_queue() from public, anon;
grant execute on function public.moderation_queue() to authenticated;

create or replace function public.set_report_status(report_id uuid, next_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'not allowed';
  end if;
  if next_status not in ('open', 'reviewing', 'closed') then
    raise exception 'bad status';
  end if;
  update public.reports set status = next_status where id = report_id;
end;
$$;

revoke all on function public.set_report_status(uuid, text) from public, anon;
grant execute on function public.set_report_status(uuid, text) to authenticated;

create or replace function public.approve_photo_verify(target_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'not allowed';
  end if;
  update public.profiles
  set photo_verified_at = now()
  where user_id = target_user;
end;
$$;

revoke all on function public.approve_photo_verify(uuid) from public, anon;
grant execute on function public.approve_photo_verify(uuid) to authenticated;

create or replace function public.export_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from public.profiles p where p.user_id = uid),
    'private_identity', (select to_jsonb(i) from public.private_identity i where i.user_id = uid),
    'health_profiles', (select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb) from public.health_profiles h where h.user_id = uid),
    'likes_sent', (select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) from public.likes l where l.from_user = uid),
    'likes_received', (select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) from public.likes l where l.to_user = uid),
    'messages', (
      select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
      from public.messages m
      join public.matches x on x.id = m.match_id
      where x.user_a = uid or x.user_b = uid
    ),
    'reports_filed', (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from public.reports r where r.reporter_id = uid),
    'trusted_contacts', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.trusted_contacts t where t.user_id = uid)
  ) into result;
  return result;
end;
$$;

revoke all on function public.export_own_account() from public, anon;
grant execute on function public.export_own_account() to authenticated;

create or replace function public.photo_verify_queue()
returns table (
  user_id uuid,
  display_name text,
  requested_at timestamptz,
  verified_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.display_name,
    p.photo_verify_requested_at as requested_at,
    p.photo_verified_at as verified_at
  from public.profiles p
  where public.is_staff()
    and p.photo_verify_requested_at is not null
    and p.photo_verified_at is null
  order by p.photo_verify_requested_at asc;
$$;

revoke all on function public.photo_verify_queue() from public, anon;
grant execute on function public.photo_verify_queue() to authenticated;

grant update on public.reports to authenticated;
