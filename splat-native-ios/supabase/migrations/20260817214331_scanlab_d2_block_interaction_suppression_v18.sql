-- D2-018: blocking is mutual for discovery and interaction visibility.
create or replace function scanlab_private.is_public_scan(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.scanlab_scans s cross join (select auth.uid() as uid) viewer
    where s.id = target and s.visibility = 'public' and s.status = 'published' and s.moderation_status = 'approved'
      and viewer.uid is not null
      and not exists (
        select 1 from public.scanlab_blocks b
        where (b.blocker_id = viewer.uid and b.blocked_id = s.owner_id)
           or (b.blocker_id = s.owner_id and b.blocked_id = viewer.uid)
      )
  );
$$;

create or replace function scanlab_private.is_reportable_scan(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.scanlab_scans s
    where s.id = target and s.visibility in ('public','unlisted') and s.status='published' and s.moderation_status='approved'
      and (select auth.uid()) is not null and s.owner_id <> (select auth.uid())
      and not exists (
        select 1 from public.scanlab_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = s.owner_id)
           or (b.blocker_id = s.owner_id and b.blocked_id = (select auth.uid()))
      )
      and not exists (
        select 1 from scanlab_private.report_dismissals d
        where d.scan_id = s.id and d.reporter_id = (select auth.uid()) and d.expires_at > pg_catalog.now()
      )
  );
$$;
