-- Permanently removes the signed-in member and their private rows.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, storage, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in before deleting this account.';
  end if;

  delete from storage.objects
  where bucket_id = 'profile-photos'
    and (name = uid::text || '/profile.jpg' or name like uid::text || '/%');

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
