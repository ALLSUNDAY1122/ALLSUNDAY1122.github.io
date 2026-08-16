create or replace function scanlab_private.is_reportable_scan(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.scanlab_scans s
    where s.id = target
      and s.visibility in ('public', 'unlisted')
      and s.status = 'published'
      and s.moderation_status = 'approved'
      and (select auth.uid()) is not null
      and s.owner_id <> (select auth.uid())
  );
$$;
revoke all on function scanlab_private.is_reportable_scan(uuid) from public, anon;
grant execute on function scanlab_private.is_reportable_scan(uuid) to authenticated;

create or replace function scanlab_private.auto_hide_reported_scan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  report_count integer;
begin
  -- Serialize report moderation for a scan so concurrent reports cannot miss the threshold.
  perform 1
  from public.scanlab_scans
  where id = new.scan_id
  for update;

  if not found then
    return new;
  end if;

  select count(distinct reporter_id) into report_count
  from public.scanlab_reports
  where scan_id = new.scan_id
    and created_at > now() - interval '30 days';

  if report_count >= 3 then
    update public.scanlab_scans
       set status = 'hidden', moderation_status = 'pending', updated_at = now()
     where id = new.scan_id
       and status = 'published'
       and moderation_status = 'approved';
  end if;

  return new;
end;
$$;
revoke all on function scanlab_private.auto_hide_reported_scan() from public, anon, authenticated;
