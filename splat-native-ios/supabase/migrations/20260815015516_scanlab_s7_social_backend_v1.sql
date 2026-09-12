create schema if not exists scanlab_private;
revoke all on schema scanlab_private from public, anon, authenticated;

create table public.scanlab_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text not null unique check (handle ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.scanlab_scans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  caption text not null default '' check (char_length(caption) <= 500),
  visibility text not null default 'private' check (visibility in ('private','unlisted','public')),
  status text not null default 'draft' check (status in ('draft','published','hidden')),
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','rejected')),
  share_token uuid not null default gen_random_uuid() unique,
  asset_path text not null,
  preview_path text,
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  location_label text check (location_label is null or char_length(location_label) <= 120),
  public_place_confirmed boolean not null default false,
  privacy_confirmed boolean not null default false,
  rights_confirmed boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scanlab_public_requires_location_and_attestation check (
    visibility <> 'public' or status <> 'published' or (
      latitude is not null and longitude is not null and
      public_place_confirmed and privacy_confirmed and rights_confirmed
    )
  )
);

create table public.scanlab_likes (
  scan_id uuid not null references public.scanlab_scans(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (scan_id, user_id)
);

create table public.scanlab_reports (
  id bigint generated always as identity primary key,
  scan_id uuid not null references public.scanlab_scans(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('privacy','unsafe_location','copyright','harassment','sexual','violence','spam','other')),
  details text not null default '' check (char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  unique (scan_id, reporter_id)
);

create index scanlab_scans_public_feed_idx on public.scanlab_scans (published_at desc) where visibility='public' and status='published' and moderation_status='approved';
create index scanlab_scans_owner_idx on public.scanlab_scans (owner_id, created_at desc);
create index scanlab_scans_map_idx on public.scanlab_scans (latitude, longitude) where visibility='public' and status='published' and moderation_status='approved' and latitude is not null and longitude is not null;
create index scanlab_likes_scan_idx on public.scanlab_likes (scan_id);
create index scanlab_reports_scan_idx on public.scanlab_reports (scan_id, created_at desc);

alter table public.scanlab_profiles enable row level security;
alter table public.scanlab_scans enable row level security;
alter table public.scanlab_likes enable row level security;
alter table public.scanlab_reports enable row level security;

revoke all on public.scanlab_profiles from anon, authenticated;
revoke all on public.scanlab_scans from anon, authenticated;
revoke all on public.scanlab_likes from anon, authenticated;
revoke all on public.scanlab_reports from anon, authenticated;

grant select on public.scanlab_profiles to anon, authenticated;
grant insert, update on public.scanlab_profiles to authenticated;
grant select on public.scanlab_scans to anon, authenticated;
grant insert, update, delete on public.scanlab_scans to authenticated;
grant select, insert, delete on public.scanlab_likes to authenticated;
grant insert on public.scanlab_reports to authenticated;
grant usage, select on sequence public.scanlab_reports_id_seq to authenticated;

create policy "scanlab public profiles readable" on public.scanlab_profiles
for select to anon, authenticated using (true);
create policy "scanlab profile owner insert" on public.scanlab_profiles
for insert to authenticated with check ((select auth.uid()) = id);
create policy "scanlab profile owner update" on public.scanlab_profiles
for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "scanlab public scans readable" on public.scanlab_scans
for select to anon, authenticated using (
  visibility='public' and status='published' and moderation_status='approved'
);
create policy "scanlab owner scans readable" on public.scanlab_scans
for select to authenticated using ((select auth.uid()) = owner_id);
create policy "scanlab owner scan insert" on public.scanlab_scans
for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "scanlab owner scan update" on public.scanlab_scans
for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "scanlab owner scan delete" on public.scanlab_scans
for delete to authenticated using ((select auth.uid()) = owner_id);

create policy "scanlab own likes readable" on public.scanlab_likes
for select to authenticated using ((select auth.uid()) = user_id);
create policy "scanlab like public scan" on public.scanlab_likes
for insert to authenticated with check (
  (select auth.uid()) = user_id and exists (
    select 1 from public.scanlab_scans s where s.id=scan_id and s.visibility='public' and s.status='published' and s.moderation_status='approved'
  )
);
create policy "scanlab unlike own" on public.scanlab_likes
for delete to authenticated using ((select auth.uid()) = user_id);

create policy "scanlab report public or unlisted" on public.scanlab_reports
for insert to authenticated with check (
  (select auth.uid()) = reporter_id and exists (
    select 1 from public.scanlab_scans s where s.id=scan_id and s.status='published' and s.visibility in ('public','unlisted')
  )
);

create or replace function scanlab_private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger scanlab_profiles_touch_updated_at
before update on public.scanlab_profiles
for each row execute function scanlab_private.touch_updated_at();
create trigger scanlab_scans_touch_updated_at
before update on public.scanlab_scans
for each row execute function scanlab_private.touch_updated_at();

create or replace function scanlab_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_handle text;
begin
  base_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 12);
  insert into public.scanlab_profiles(id, handle, display_name)
  values (new.id, base_handle, 'Scan Lab User')
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function scanlab_private.handle_new_user() from public, anon, authenticated;

create trigger scanlab_auth_user_created
after insert on auth.users
for each row execute function scanlab_private.handle_new_user();

create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  recent_count integer;
begin
  if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published') then
    if new.visibility='public' and (new.latitude is null or new.longitude is null or not new.public_place_confirmed or not new.privacy_confirmed or not new.rights_confirmed) then
      raise exception 'public scan requires location and safety attestations';
    end if;
    if new.visibility in ('public','unlisted') then
      select count(*) into recent_count
      from public.scanlab_scans
      where owner_id=new.owner_id and status='published' and visibility in ('public','unlisted')
        and published_at > now() - interval '1 hour';
      if recent_count >= 10 then
        raise exception 'publish rate limit exceeded';
      end if;
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;
  if new.status <> 'published' then
    new.published_at := null;
  end if;
  return new;
end;
$$;

create trigger scanlab_scan_publish_guard
before insert or update of status, visibility on public.scanlab_scans
for each row execute function scanlab_private.publish_guard();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scanlab-assets','scanlab-assets',false,134217728,array['application/octet-stream','image/jpeg','image/png'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create policy "scanlab storage owner read" on storage.objects
for select to authenticated using (
  bucket_id='scanlab-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "scanlab storage owner insert" on storage.objects
for insert to authenticated with check (
  bucket_id='scanlab-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "scanlab storage owner update" on storage.objects
for update to authenticated using (
  bucket_id='scanlab-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
) with check (
  bucket_id='scanlab-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "scanlab storage owner delete" on storage.objects
for delete to authenticated using (
  bucket_id='scanlab-assets' and (storage.foldername(name))[1] = (select auth.uid())::text
);
