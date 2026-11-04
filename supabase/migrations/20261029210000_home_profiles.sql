-- Home shows other finished profiles, with a profile photo when one is stored.
-- The photo bucket stays private. Signed-in members can see a photo on a
-- profile card. This is not a public directory, and it is not a street address.

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
  photo_path text
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
    ) as photo_path
  from public.profiles p
  left join public.private_identity i on i.user_id = p.user_id
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id);
$$;

comment on function public.discovery_cards() is
  'Finished profiles for Home. Returns age and a private photo path, never a date of birth, HIV status, street address, or GPS point.';

revoke all on function public.discovery_cards() from public, anon;
grant execute on function public.discovery_cards() to authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    execute $policy$
      drop policy if exists profile_photos_member_read on storage.objects;
      create policy profile_photos_member_read on storage.objects
        for select to authenticated
        using (
          bucket_id = 'profile-photos'
          and exists (
            select 1
            from public.profiles p
            where p.user_id::text = (storage.foldername(name))[1]
              and (
                p.user_id = auth.uid()
                or (
                  p.onboarding_completed = true
                  and p.account_paused = false
                  and not private.pair_is_blocked(auth.uid(), p.user_id)
                )
              )
          )
        );
    $policy$;
  end if;
end $$;
