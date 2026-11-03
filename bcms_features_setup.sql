-- BCMS clan profiles, leaderboard, wars and clip approvals
alter table public.clan_applications add column if not exists clan_skin_link text;
alter table public.clan_applications add column if not exists profile_image_url text;
alter table public.clans add column if not exists clan_skin_link text;
alter table public.clans add column if not exists profile_image_url text;
alter table public.clans add column if not exists discord_link text;

create table if not exists public.bcms_leaderboard (
 id uuid primary key default gen_random_uuid(),
 player_name text not null,
 clan_id uuid references public.clans(id) on delete set null,
 points integer not null default 0,
 wins integer not null default 0,
 losses integer not null default 0,
 updated_at timestamptz not null default now()
);
create table if not exists public.bcms_wars (
 id uuid primary key default gen_random_uuid(),
 clan_one_id uuid references public.clans(id) on delete set null,
 clan_two_id uuid references public.clans(id) on delete set null,
 title text not null,
 status text not null default 'live' check(status in ('live','upcoming','completed')),
 score_one integer not null default 0,
 score_two integer not null default 0,
 match_link text,
 created_at timestamptz not null default now()
);
create table if not exists public.bcms_war_clips (
 id uuid primary key default gen_random_uuid(),
 war_id uuid references public.bcms_wars(id) on delete set null,
 uploader_id uuid not null references auth.users(id) on delete cascade,
 title text not null,
 video_url text not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now()
);

alter table public.bcms_leaderboard enable row level security;
alter table public.bcms_wars enable row level security;
alter table public.bcms_war_clips enable row level security;

drop policy if exists "Public read BCMS leaderboard" on public.bcms_leaderboard;
create policy "Public read BCMS leaderboard" on public.bcms_leaderboard for select using (true);
drop policy if exists "Staff manage BCMS leaderboard" on public.bcms_leaderboard;
create policy "Staff manage BCMS leaderboard" on public.bcms_leaderboard for all to authenticated using (public.has_bcms_role(array['founder','admin','moderator'])) with check (public.has_bcms_role(array['founder','admin','moderator']));

drop policy if exists "Public read BCMS wars" on public.bcms_wars;
create policy "Public read BCMS wars" on public.bcms_wars for select using (true);
drop policy if exists "Staff manage BCMS wars" on public.bcms_wars;
create policy "Staff manage BCMS wars" on public.bcms_wars for all to authenticated using (public.has_bcms_role(array['founder','admin','moderator'])) with check (public.has_bcms_role(array['founder','admin','moderator']));

drop policy if exists "Public read approved BCMS clips" on public.bcms_war_clips;
create policy "Public read approved BCMS clips" on public.bcms_war_clips for select using (status='approved' or public.has_bcms_role(array['founder','admin','moderator']));
drop policy if exists "Members submit BCMS clips" on public.bcms_war_clips;
create policy "Members submit BCMS clips" on public.bcms_war_clips for insert to authenticated with check (uploader_id=auth.uid() and status='pending');
drop policy if exists "Staff review BCMS clips" on public.bcms_war_clips;
create policy "Staff review BCMS clips" on public.bcms_war_clips for update to authenticated using (public.has_bcms_role(array['founder','admin','moderator'])) with check (public.has_bcms_role(array['founder','admin','moderator']));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('clan-assets','clan-assets',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('war-clips','war-clips',true,104857600,array['video/mp4','video/webm','video/quicktime'])
on conflict(id) do nothing;

drop policy if exists "Public read clan assets" on storage.objects;
create policy "Public read clan assets" on storage.objects for select using(bucket_id='clan-assets');
drop policy if exists "Members upload clan assets" on storage.objects;
create policy "Members upload clan assets" on storage.objects for insert to authenticated with check(bucket_id='clan-assets' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Public read war clips" on storage.objects;
create policy "Public read war clips" on storage.objects for select using(bucket_id='war-clips');
drop policy if exists "Members upload war clips" on storage.objects;
create policy "Members upload war clips" on storage.objects for insert to authenticated with check(bucket_id='war-clips' and (storage.foldername(name))[1]=auth.uid()::text);
