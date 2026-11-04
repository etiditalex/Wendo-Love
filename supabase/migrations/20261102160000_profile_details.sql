-- Optional appearance and living details for Edit Profile.
-- These are self-described. They are never a clinic record, HIV status,
-- street address, or GPS point. Occupation already exists on profiles.

alter table public.profiles
  add column if not exists hair_color text,
  add column if not exists eye_color text,
  add column if not exists height_label text,
  add column if not exists weight_label text,
  add column if not exists body_type text,
  add column if not exists ethnicity text,
  add column if not exists children_count text,
  add column if not exists oldest_child text,
  add column if not exists youngest_child text,
  add column if not exists has_pets text,
  add column if not exists employment_status text,
  add column if not exists income_range text,
  add column if not exists living_situation text;

comment on column public.profiles.hair_color is
  'Optional self-described appearance. Never used to rank people.';
comment on column public.profiles.occupation is
  'Optional work or study description. Not a clinic, employer ID, or payroll record.';
comment on column public.profiles.living_situation is
  'Optional household description. Never a street address or GPS point.';
comment on column public.profiles.income_range is
  'Optional broad label. Not a bank statement, salary figure, or means test.';
