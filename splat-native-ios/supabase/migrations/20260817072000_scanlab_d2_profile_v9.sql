-- D2-003 profile/public-profile/avatar contract.
-- Base profile rows remain owner-only via RLS. Public exposure is an explicit RPC
-- returning only display-safe fields and never email or storage paths.

alter table public.scanlab_profiles
  add column if not exists bio text,
  add column if not exists avatar_url text;

alter table public.scanlab_profiles
  drop constraint if exists scanlab_profiles_bio_length;
alter table public.scanlab_profiles
  add constraint scanlab_profiles_bio_length
  check (bio is null or char_length(bio) <= 160);

alter table public.scanlab_profiles
  drop constraint if exists scanlab_profiles_avatar_url_https;
alter table public.scanlab_profiles
  add constraint scanlab_profiles_avatar_url_https
  check (avatar_url is null or (char_length(avatar_url) <= 2048 and avatar_url ~ '^https://'));

create or replace function public.scanlab_public_profile(p_handle text)
returns table (
  id uuid,
  handle text,
  display_name text,
  bio text,
  avatar_url text,
  public_scan_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.handle,
    p.display_name,
    p.bio,
    p.avatar_url,
    count(s.id)::bigint
  from public.scanlab_profiles p
  left join public.scanlab_scans s
    on s.owner_id = p.id
   and s.visibility = 'public'
   and s.status = 'published'
   and s.moderation_status = 'approved'
  where p.handle = lower(trim(p_handle))
  group by p.id, p.handle, p.display_name, p.bio, p.avatar_url
  limit 1;
$$;

revoke all on function public.scanlab_public_profile(text) from public;
grant execute on function public.scanlab_public_profile(text) to anon, authenticated;

comment on function public.scanlab_public_profile(text) is
'D2-003 public profile projection. Intentionally excludes email, avatar_path and non-public scans.';
