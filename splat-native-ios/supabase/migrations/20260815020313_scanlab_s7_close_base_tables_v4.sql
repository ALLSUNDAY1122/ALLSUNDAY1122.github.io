drop policy if exists "scanlab public scans readable" on public.scanlab_scans;
revoke select on public.scanlab_scans from anon;

create or replace function public.scanlab_is_public_scan(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.scanlab_scans s
    where s.id=target and s.visibility='public' and s.status='published' and s.moderation_status='approved'
  );
$$;
revoke all on function public.scanlab_is_public_scan(uuid) from public, anon;
grant execute on function public.scanlab_is_public_scan(uuid) to authenticated;

create or replace function public.scanlab_is_reportable_scan(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.scanlab_scans s
    where s.id=target and s.visibility in ('public','unlisted') and s.status='published' and s.moderation_status='approved'
  );
$$;
revoke all on function public.scanlab_is_reportable_scan(uuid) from public, anon;
grant execute on function public.scanlab_is_reportable_scan(uuid) to authenticated;

drop policy if exists "scanlab like public scan" on public.scanlab_likes;
create policy "scanlab like public scan" on public.scanlab_likes
for insert to authenticated with check (
  (select auth.uid()) = user_id and public.scanlab_is_public_scan(scan_id)
);

drop policy if exists "scanlab report public or unlisted" on public.scanlab_reports;
create policy "scanlab report public or unlisted" on public.scanlab_reports
for insert to authenticated with check (
  (select auth.uid()) = reporter_id and public.scanlab_is_reportable_scan(scan_id)
);
