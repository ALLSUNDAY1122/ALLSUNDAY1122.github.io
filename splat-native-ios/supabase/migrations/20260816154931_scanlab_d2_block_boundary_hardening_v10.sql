create or replace function scanlab_private.is_public_scan(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.scanlab_scans s
    cross join (select auth.uid() as uid) viewer
    where s.id = target
      and s.visibility = 'public'
      and s.status = 'published'
      and s.moderation_status = 'approved'
      and viewer.uid is not null
      and not exists (
        select 1
        from public.scanlab_blocks b
        where (b.blocker_id = viewer.uid and b.blocked_id = s.owner_id)
           or (b.blocker_id = s.owner_id and b.blocked_id = viewer.uid)
      )
  );
$$;
revoke all on function scanlab_private.is_public_scan(uuid) from public, anon;
grant execute on function scanlab_private.is_public_scan(uuid) to authenticated;
