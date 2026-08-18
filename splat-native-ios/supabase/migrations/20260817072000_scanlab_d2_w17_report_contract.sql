-- D2-017: report reason / persistence / duplicate-report prevention.
-- Keep reports write-only to clients; moderation reads remain service-side only.

alter table public.scanlab_reports
  add column if not exists updated_at timestamptz not null default now();

-- A reporter gets one durable report per scan. The existing unique(scan_id, reporter_id)
-- is retained as the database-level race-condition backstop.
create index if not exists scanlab_reports_reporter_idx
  on public.scanlab_reports (reporter_id, created_at desc);

create or replace function scanlab_private.touch_report_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function scanlab_private.touch_report_updated_at() from public, anon, authenticated;

drop trigger if exists scanlab_reports_touch_updated_at on public.scanlab_reports;
create trigger scanlab_reports_touch_updated_at
before update on public.scanlab_reports
for each row execute function scanlab_private.touch_report_updated_at();

-- Do not expose report rows through table SELECT. This RPC only reveals whether the
-- current authenticated user has already reported a specific scan, without leaking
-- another reporter, reason, details, moderation state, or report counts.
create or replace function public.scanlab_has_reported(target_scan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (select auth.uid()) is null then false
    else exists (
      select 1
      from public.scanlab_reports r
      where r.scan_id = target_scan_id
        and r.reporter_id = (select auth.uid())
    )
  end;
$$;

revoke all on function public.scanlab_has_reported(uuid) from public, anon;
grant execute on function public.scanlab_has_reported(uuid) to authenticated;

-- Submit atomically. A concurrent duplicate resolves to the already-persisted row,
-- so clients can render a deterministic duplicate state instead of treating 23505 as
-- an unknown transport failure. The original reason/details are intentionally kept.
create or replace function public.scanlab_submit_report(
  target_scan_id uuid,
  report_reason text,
  report_details text default ''
)
returns table(report_id bigint, duplicate boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  existing public.scanlab_reports%rowtype;
  inserted public.scanlab_reports%rowtype;
begin
  if uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if report_reason is null or report_reason not in
    ('privacy','unsafe_location','copyright','harassment','sexual','violence','spam','other') then
    raise exception 'invalid report reason' using errcode = '22023';
  end if;

  if char_length(coalesce(report_details, '')) > 1000 then
    raise exception 'report details too long' using errcode = '22001';
  end if;

  if not exists (
    select 1 from public.scanlab_scans s
    where s.id = target_scan_id
      and s.status = 'published'
      and s.visibility in ('public','unlisted')
      and s.owner_id <> uid
  ) then
    raise exception 'scan is not reportable' using errcode = '42501';
  end if;

  select * into existing
  from public.scanlab_reports r
  where r.scan_id = target_scan_id and r.reporter_id = uid;

  if found then
    return query select existing.id, true, existing.created_at;
    return;
  end if;

  begin
    insert into public.scanlab_reports(scan_id, reporter_id, reason, details)
    values (target_scan_id, uid, report_reason, coalesce(report_details, ''))
    returning * into inserted;
  exception when unique_violation then
    select * into existing
    from public.scanlab_reports r
    where r.scan_id = target_scan_id and r.reporter_id = uid;
    return query select existing.id, true, existing.created_at;
    return;
  end;

  return query select inserted.id, false, inserted.created_at;
end;
$$;

revoke all on function public.scanlab_submit_report(uuid, text, text) from public, anon;
grant execute on function public.scanlab_submit_report(uuid, text, text) to authenticated;

-- Force report creation through the validated RPC. This also prevents a client from
-- spoofing reporter_id by attempting a direct table INSERT.
revoke insert on public.scanlab_reports from authenticated;
