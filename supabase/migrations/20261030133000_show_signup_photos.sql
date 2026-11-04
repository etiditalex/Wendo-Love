-- Signed-in members can see the photo saved when an account was created.
-- The bucket stays private. This is not a public directory.

drop policy if exists photos_member_read on public.profile_photos;
create policy photos_member_read on public.profile_photos
  for select to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.user_id = profile_photos.user_id
        and p.onboarding_completed = true
        and p.account_paused = false
        and (
          p.user_id = auth.uid()
          or not private.pair_is_blocked(auth.uid(), p.user_id)
        )
    )
  );

create or replace function public.profile_photo_paths()
returns table (
  user_id uuid,
  storage_path text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.user_id, ph.storage_path
  from public.profiles p
  join public.profile_photos ph on ph.user_id = p.user_id
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.account_paused = false
    and p.onboarding_completed = true
    and not private.pair_is_blocked(auth.uid(), p.user_id);
$$;

comment on function public.profile_photo_paths() is
  'Photo file paths for finished profiles. Returns the private storage path only, never a date of birth or HIV status.';

revoke all on function public.profile_photo_paths() from public, anon;
grant execute on function public.profile_photo_paths() to authenticated;

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
