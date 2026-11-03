-- BCMS live chat setup and access rules
create table if not exists public.chat_messages (
 id uuid primary key default gen_random_uuid(),
 channel_type text not null check(channel_type in ('community','leaders','clan','staff')),
 clan_id uuid references public.clans(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 sender_name text not null default 'Member',
 content text not null check(char_length(trim(content)) between 1 and 1000),
 created_at timestamptz not null default now(),
 check ((channel_type='clan' and clan_id is not null) or (channel_type<>'clan' and clan_id is null))
);
alter table public.chat_messages add column if not exists sender_name text not null default 'Member';
alter table public.chat_messages enable row level security;
drop policy if exists "BCMS chat members can read allowed rooms" on public.chat_messages;
drop policy if exists "BCMS chat members can send to allowed rooms" on public.chat_messages;
create policy "BCMS chat members can read allowed rooms" on public.chat_messages
for select to authenticated using (
 (channel_type='community')
 or (channel_type='leaders' and (
   exists(select 1 from public.clans c where c.leader_id=auth.uid())
   or exists(select 1 from public.clan_members cm where cm.user_id=auth.uid() and cm.role='leader')
 ))
 or (channel_type='clan' and exists(
   select 1 from public.clan_members cm where cm.user_id=auth.uid() and cm.clan_id=chat_messages.clan_id
 ))
 or (channel_type='staff' and exists(
   select 1 from public.organization_staff os where os.user_id=auth.uid()
 ))
);
create policy "BCMS chat members can send to allowed rooms" on public.chat_messages
for insert to authenticated with check (
 sender_id=auth.uid() and char_length(trim(content)) between 1 and 1000
 and (
  channel_type='community'
  or (channel_type='leaders' and (
    exists(select 1 from public.clans c where c.leader_id=auth.uid())
    or exists(select 1 from public.clan_members cm where cm.user_id=auth.uid() and cm.role='leader')
  ))
  or (channel_type='clan' and exists(
    select 1 from public.clan_members cm where cm.user_id=auth.uid() and cm.clan_id=chat_messages.clan_id
  ))
  or (channel_type='staff' and exists(
    select 1 from public.organization_staff os where os.user_id=auth.uid()
  ))
 )
);
do $$
begin
 if not exists (
  select 1 from pg_publication_tables
  where pubname='supabase_realtime' and schemaname='public' and tablename='chat_messages'
 ) then
  alter publication supabase_realtime add table public.chat_messages;
 end if;
end $$;
