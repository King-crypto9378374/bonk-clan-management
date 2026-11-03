-- BCMS leaderboard, war format, and diplomacy upgrade
alter table public.bcms_leaderboard add column if not exists elo integer not null default 1000;
alter table public.bcms_leaderboard add column if not exists mode_stats jsonb not null default '{}'::jsonb;
alter table public.bcms_leaderboard add column if not exists matches_played integer not null default 0;
alter table public.bcms_leaderboard add column if not exists win_percentage numeric(5,2) not null default 0;
create unique index if not exists bcms_leaderboard_player_name_unique on public.bcms_leaderboard (lower(player_name));

create table if not exists public.bcms_stat_submissions (
 id uuid primary key default gen_random_uuid(),
 clan_id uuid not null references public.clans(id) on delete cascade,
 submitted_by uuid not null references auth.users(id) on delete cascade,
 player_name text not null,
 elo integer not null default 1000,
 mode_stats jsonb not null default '{}'::jsonb,
 notes text,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now()
);
alter table public.bcms_stat_submissions enable row level security;
drop policy if exists "Public read approved leaderboard stats" on public.bcms_leaderboard;
drop policy if exists "Clan leaders submit stats" on public.bcms_stat_submissions;
create policy "Clan leaders submit stats" on public.bcms_stat_submissions
for insert to authenticated with check (
 submitted_by=auth.uid() and status='pending'
 and exists(select 1 from public.clan_members cm where cm.clan_id=bcms_stat_submissions.clan_id and cm.user_id=auth.uid() and cm.role='leader')
);
drop policy if exists "Staff review stat submissions" on public.bcms_stat_submissions;
create policy "Staff review stat submissions" on public.bcms_stat_submissions
for all to authenticated using(public.has_bcms_role(array['founder','admin','moderator']))
with check(public.has_bcms_role(array['founder','admin','moderator']));
drop policy if exists "Staff manage BCMS leaderboard" on public.bcms_leaderboard;
create policy "Staff manage BCMS leaderboard" on public.bcms_leaderboard
for all to authenticated using(public.has_bcms_role(array['founder','admin','moderator']))
with check(public.has_bcms_role(array['founder','admin','moderator']));

alter table public.bcms_wars add column if not exists maps jsonb not null default '{}'::jsonb;
alter table public.bcms_wars add column if not exists format_note text default '5 modes, 5 rounds per mode';
create table if not exists public.bcms_diplomacy (
 id uuid primary key default gen_random_uuid(),
 from_clan_id uuid not null references public.clans(id) on delete cascade,
 to_clan_id uuid not null references public.clans(id) on delete cascade,
 request_type text not null check(request_type in ('ally','war')),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 message text,
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(from_clan_id <> to_clan_id)
);
alter table public.bcms_diplomacy enable row level security;
drop policy if exists "Public read diplomacy" on public.bcms_diplomacy;
create policy "Public read diplomacy" on public.bcms_diplomacy for select using(true);
drop policy if exists "Clan leaders create diplomacy" on public.bcms_diplomacy;
create policy "Clan leaders create diplomacy" on public.bcms_diplomacy
for insert to authenticated with check (
 created_by=auth.uid() and exists(select 1 from public.clan_members cm where cm.clan_id=from_clan_id and cm.user_id=auth.uid() and cm.role='leader')
);
drop policy if exists "Clan leaders respond diplomacy" on public.bcms_diplomacy;
create policy "Clan leaders respond diplomacy" on public.bcms_diplomacy
for update to authenticated using (
 exists(select 1 from public.clan_members cm where cm.clan_id=to_clan_id and cm.user_id=auth.uid() and cm.role='leader')
) with check (
 exists(select 1 from public.clan_members cm where cm.clan_id=to_clan_id and cm.user_id=auth.uid() and cm.role='leader')
);
