-- A like is visible to the person who received it.
-- A message can be sent while the other person is away. It waits for them.
-- A conversation started by a message is not a mutual match for health sharing.

alter table public.matches
  add column if not exists is_mutual boolean not null default false;

update public.matches m
set is_mutual = true
where exists (
  select 1
  from public.likes a
  join public.likes b
    on a.from_user = b.to_user
   and a.to_user = b.from_user
  where a.from_user = m.user_a
    and a.to_user = m.user_b
);

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
    insert into public.matches (user_a, user_b, is_mutual)
    values (least(new.from_user, new.to_user), greatest(new.from_user, new.to_user), true)
    on conflict (user_a, user_b) do update
      set is_mutual = true;
  end if;
  return new;
end;
$$;

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
      and is_mutual = true
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

drop policy if exists likes_read_incoming on public.likes;
create policy likes_read_incoming on public.likes
  for select to authenticated
  using (to_user = auth.uid());

create table if not exists public.message_reads (
  user_id uuid not null references auth.users (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, match_id)
);

alter table public.message_reads enable row level security;
alter table public.message_reads force row level security;

drop policy if exists message_reads_owner on public.message_reads;
create policy message_reads_owner on public.message_reads
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.matches m
      where m.id = match_id
        and auth.uid() in (m.user_a, m.user_b)
    )
  );

grant select, insert, update, delete on public.message_reads to authenticated;

create or replace function public.open_conversation(other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  match_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to send a message';
  end if;
  if other_user is null or other_user = auth.uid() then
    raise exception 'Choose another member';
  end if;
  if private.pair_is_blocked(auth.uid(), other_user) then
    raise exception 'This conversation is closed';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.user_id = other_user
      and p.onboarding_completed = true
      and p.account_paused = false
  ) then
    raise exception 'That profile is not available';
  end if;

  insert into public.matches (user_a, user_b)
  values (least(auth.uid(), other_user), greatest(auth.uid(), other_user))
  on conflict (user_a, user_b) do update
    set unmatched_at = null,
        unmatched_by = null
  returning id into match_id;

  return match_id;
end;
$$;

comment on function public.open_conversation(uuid) is
  'Starts or reopens a private conversation. The other person does not need to be in the app. This does not share health information.';

revoke all on function public.open_conversation(uuid) from public, anon;
grant execute on function public.open_conversation(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'likes'
     ) then
    alter publication supabase_realtime add table public.likes;
  end if;
end $$;
