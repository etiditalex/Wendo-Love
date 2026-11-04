-- Extra profile photos, hobbies, and personality answers.
-- None of this is HIV status, a clinic record, a street address, or GPS.
-- Extra photos stay in the private profile-photos bucket.

alter table public.profiles
  add column if not exists about_answers jsonb not null default '{}'::jsonb,
  add column if not exists photo_verify_requested_at timestamptz;

comment on column public.profiles.about_answers is
  'Optional hobbies and personality answers. They introduce a person. They are never used to hide people or to rank by health.';

comment on column public.profiles.photo_verify_requested_at is
  'When a member sent a private confirmation photo. Not a health badge and not a ranking flag.';
