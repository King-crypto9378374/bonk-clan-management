-- BCMS diplomacy privacy, alliance directory, and accepted war challenges
alter table public.bcms_diplomacy enable row level security;
drop policy if exists "Public read diplomacy" on public.bcms_diplomacy;
drop policy if exists "Clan leaders create diplomacy" on public.bcms_diplomacy;
drop policy if exists "Clan leaders respond diplomacy" on public.bcms_diplomacy;
drop policy if exists "Leaders view their diplomacy" on public.bcms_diplomacy;
create policy "Leaders view their diplomacy" on public.bcms_diplomacy
for select to authenticated using (
 exists(select 1 from public.clans c where c.id=from_clan_id and c.leader_id=auth.uid())
 or exists(select 1 from public.clans c where c.id=to_clan_id and c.leader_id=auth.uid())
 or exists(select 1 from public.clan_members cm where cm.clan_id=from_clan_id and cm.user_id=auth.uid() and cm.role='leader')
 or exists(select 1 from public.clan_members cm where cm.clan_id=to_clan_id and cm.user_id=auth.uid() and cm.role='leader')
);
create policy "Clan leaders create diplomacy" on public.bcms_diplomacy
for insert to authenticated with check (
 created_by=auth.uid() and (
  exists(select 1 from public.clans c where c.id=from_clan_id and c.leader_id=auth.uid())
  or exists(select 1 from public.clan_members cm where cm.clan_id=from_clan_id and cm.user_id=auth.uid() and cm.role='leader')
 )
);
create policy "Clan leaders respond diplomacy" on public.bcms_diplomacy
for update to authenticated using (
 exists(select 1 from public.clans c where c.id=to_clan_id and c.leader_id=auth.uid())
 or exists(select 1 from public.clan_members cm where cm.clan_id=to_clan_id and cm.user_id=auth.uid() and cm.role='leader')
) with check (
 exists(select 1 from public.clans c where c.id=to_clan_id and c.leader_id=auth.uid())
 or exists(select 1 from public.clan_members cm where cm.clan_id=to_clan_id and cm.user_id=auth.uid() and cm.role='leader')
);
create table if not exists public.bcms_clan_alliances (
 id uuid primary key default gen_random_uuid(),
 clan_one_id uuid not null references public.clans(id) on delete cascade,
 clan_two_id uuid not null references public.clans(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(clan_one_id <> clan_two_id),
 unique(clan_one_id,clan_two_id)
);
alter table public.bcms_clan_alliances enable row level security;
drop policy if exists "Public read clan alliances" on public.bcms_clan_alliances;
create policy "Public read clan alliances" on public.bcms_clan_alliances for select using(true);
create or replace function public.bcms_process_accepted_diplomacy()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status='accepted' and old.status is distinct from new.status then
  if new.request_type='ally' then
   insert into public.bcms_clan_alliances(clan_one_id,clan_two_id)
   values(least(new.from_clan_id,new.to_clan_id),greatest(new.from_clan_id,new.to_clan_id))
   on conflict(clan_one_id,clan_two_id) do nothing;
  elsif new.request_type='war' then
   insert into public.bcms_wars(clan_one_id,clan_two_id,title,status,score_one,score_two)
   values(new.from_clan_id,new.to_clan_id,
    (select name from public.clans where id=new.from_clan_id)||' vs '||(select name from public.clans where id=new.to_clan_id),
    'live',0,0);
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists bcms_accepted_diplomacy_action on public.bcms_diplomacy;
create trigger bcms_accepted_diplomacy_action after update of status on public.bcms_diplomacy
for each row execute function public.bcms_process_accepted_diplomacy();
