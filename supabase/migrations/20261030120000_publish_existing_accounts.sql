-- Every account becomes a profile other members can see.
-- The person does not have to stay signed in. Signing out does not hide the profile.
-- This also publishes accounts that were created before this change.
-- Date of birth and HIV status are not copied here.

create or replace function public.publish_account_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  chosen_name text;
begin
  chosen_name := btrim(coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1)));
  if chosen_name is null or char_length(chosen_name) < 2 then
    chosen_name := 'Member';
  elsif char_length(chosen_name) > 40 then
    chosen_name := left(chosen_name, 40);
  end if;

  insert into public.profiles (
    user_id,
    display_name,
    relationship_intent,
    onboarding_completed,
    account_paused
  )
  values (new.id, chosen_name, 'unsure', true, false)
  on conflict (user_id) do update
    set onboarding_completed = true
    where public.profiles.account_paused = false
      and public.profiles.onboarding_completed = false;

  return new;
end;
$$;

revoke all on function public.publish_account_profile() from public, anon, authenticated;

drop trigger if exists publish_account_profile on auth.users;
create trigger publish_account_profile
  after insert on auth.users
  for each row execute function public.publish_account_profile();

insert into public.profiles (
  user_id,
  display_name,
  relationship_intent,
  onboarding_completed,
  account_paused
)
select
  u.id,
  case
    when char_length(btrim(coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email, ''), '@', 1)))) between 2 and 40
      then btrim(coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email, ''), '@', 1)))
    when char_length(btrim(coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email, ''), '@', 1)))) > 40
      then left(btrim(coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email, ''), '@', 1))), 40)
    else 'Member'
  end,
  'unsure',
  true,
  false
from auth.users u
on conflict (user_id) do update
  set onboarding_completed = true
  where public.profiles.account_paused = false
    and public.profiles.onboarding_completed = false;
