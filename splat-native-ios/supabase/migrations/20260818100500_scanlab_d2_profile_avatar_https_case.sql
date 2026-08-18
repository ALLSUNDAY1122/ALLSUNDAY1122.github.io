-- D2-003 regression: Swift URL validation treats HTTPS scheme case-insensitively.
-- Keep the database contract aligned so a client-valid avatar URL cannot fail only at persistence time.

alter table public.scanlab_profiles drop constraint if exists scanlab_profiles_avatar_url_https;
alter table public.scanlab_profiles
  add constraint scanlab_profiles_avatar_url_https
  check (avatar_url is null or (char_length(avatar_url) <= 2048 and avatar_url ~* '^https://'));
