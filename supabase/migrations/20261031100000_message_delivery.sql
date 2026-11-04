-- Let either person in a match see when the other opened the thread,
-- so sent messages can show Delivered / Read.

drop policy if exists message_reads_partner_read on public.message_reads;
create policy message_reads_partner_read on public.message_reads
  for select to authenticated
  using (
    exists (
      select 1
      from public.matches m
      where m.id = match_id
        and m.unmatched_at is null
        and auth.uid() in (m.user_a, m.user_b)
        and message_reads.user_id in (m.user_a, m.user_b)
    )
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'message_reads'
    ) then
      alter publication supabase_realtime add table public.message_reads;
    end if;
  end if;
end $$;
