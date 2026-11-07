revoke insert, update on public.scanlab_scans from authenticated;
grant insert (owner_id, title, caption, visibility, status, asset_path, preview_path, latitude, longitude, location_label, public_place_confirmed, privacy_confirmed, rights_confirmed) on public.scanlab_scans to authenticated;
grant update (title, caption, visibility, status, asset_path, preview_path, latitude, longitude, location_label, public_place_confirmed, privacy_confirmed, rights_confirmed) on public.scanlab_scans to authenticated;

create or replace function scanlab_private.auto_hide_reported_scan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  report_count integer;
begin
  select count(*) into report_count
  from public.scanlab_reports
  where scan_id = new.scan_id and created_at > now() - interval '30 days';

  if report_count >= 3 then
    update public.scanlab_scans
       set status='hidden', moderation_status='pending', updated_at=now()
     where id=new.scan_id and status='published';
  end if;
  return new;
end;
$$;
revoke all on function scanlab_private.auto_hide_reported_scan() from public, anon, authenticated;

create trigger scanlab_reports_auto_hide
after insert on public.scanlab_reports
for each row execute function scanlab_private.auto_hide_reported_scan();
