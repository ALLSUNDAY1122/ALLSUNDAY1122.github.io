create table scanlab_private.moderation_reviews (
  id bigint generated always as identity primary key,
  scan_id uuid references public.scanlab_scans(id) on delete set null,
  decision text not null check (decision in ('approve', 'reject')),
  report_count integer not null check (report_count > 0),
  reason_counts jsonb not null default '{}'::jsonb,
  reviewer_role text not null,
  note text not null default '',
  created_at timestamptz not null default pg_catalog.now(),
  constraint scanlab_moderation_review_note_check check (char_length(note) <= 1000)
);

alter table scanlab_private.moderation_reviews enable row level security;
revoke all on table scanlab_private.moderation_reviews from public, anon, authenticated;

create table scanlab_private.report_dismissals (
  scan_id uuid not null references public.scanlab_scans(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  dismissed_at timestamptz not null default pg_catalog.now(),
  expires_at timestamptz not null,
  review_id bigint not null references scanlab_private.moderation_reviews(id),
  primary key (scan_id, reporter_id),
  constraint scanlab_report_dismissal_expiry_check check (expires_at > dismissed_at)
);

create index scanlab_report_dismissals_reporter_idx
  on scanlab_private.report_dismissals(reporter_id);

alter table scanlab_private.report_dismissals enable row level security;
revoke all on table scanlab_private.report_dismissals from public, anon, authenticated;

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
      and not exists (
        select 1
        from scanlab_private.report_dismissals d
        where d.scan_id = s.id
          and d.reporter_id = (select auth.uid())
          and d.expires_at > pg_catalog.now()
      )
  );
$$;
revoke all on function scanlab_private.is_reportable_scan(uuid) from public, anon;
grant execute on function scanlab_private.is_reportable_scan(uuid) to authenticated;

create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entering_shared boolean := false;
  moderation_restore boolean := false;
begin
  if new.status = 'published' and new.visibility in ('public', 'unlisted') then
    if tg_op = 'INSERT' then
      entering_shared := true;
    else
      entering_shared :=
        old.status is distinct from 'published'
        or old.visibility not in ('public', 'unlisted');
    end if;

    if not new.content_confirmed then
      raise exception 'shared scan requires content confirmation';
    end if;

    if new.visibility = 'public' then
      if not new.privacy_confirmed or not new.rights_confirmed then
        raise exception 'public scan requires privacy and rights attestations';
      end if;

      if (new.latitude is null and new.longitude is not null)
         or (new.latitude is not null and new.longitude is null) then
        raise exception 'public geotag requires both coordinates';
      end if;

      if new.latitude is not null and not new.public_place_confirmed then
        raise exception 'public geotag requires public-place attestation';
      end if;
    end if;
  end if;

  if entering_shared then
    moderation_restore := coalesce(
      pg_catalog.current_setting('scanlab.moderation_restore', true),
      ''
    ) = '1';

    if not moderation_restore then
      perform scanlab_private.consume_rate_limit(
        new.owner_id,
        'publish_shared',
        10,
        interval '1 hour'
      );
    end if;

    new.published_at := pg_catalog.now();
  elsif new.status = 'published' then
    if tg_op = 'INSERT' then
      new.published_at := coalesce(new.published_at, pg_catalog.now());
    elsif old.status is distinct from 'published' then
      new.published_at := coalesce(new.published_at, pg_catalog.now());
    end if;
  end if;

  if new.status <> 'published' then
    new.published_at := null;
  end if;

  return new;
end;
$$;
revoke all on function scanlab_private.publish_guard() from public, anon, authenticated;

create or replace function public.scanlab_moderation_queue(limit_count integer default 100)
returns table (
  scan_id uuid,
  owner_id uuid,
  title text,
  visibility text,
  status text,
  moderation_status text,
  report_count bigint,
  reason_counts jsonb,
  reports jsonb,
  latest_report_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if limit_count < 1 or limit_count > 200 then
    raise exception 'invalid moderation queue limit';
  end if;

  return query
  select
    s.id,
    s.owner_id,
    s.title,
    s.visibility,
    s.status,
    s.moderation_status,
    count(r.id)::bigint,
    coalesce(
      (
        select pg_catalog.jsonb_object_agg(reason_group.reason, reason_group.reason_count)
        from (
          select r2.reason, count(*)::bigint as reason_count
          from public.scanlab_reports r2
          where r2.scan_id = s.id
          group by r2.reason
        ) reason_group
      ),
      '{}'::jsonb
    ),
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'reason', r.reason,
        'details', r.details,
        'createdAt', r.created_at
      )
      order by r.created_at asc
    ),
    max(r.created_at)
  from public.scanlab_scans s
  join public.scanlab_reports r on r.scan_id = s.id
  where s.moderation_status in ('approved', 'pending')
  group by s.id, s.owner_id, s.title, s.visibility, s.status, s.moderation_status
  order by max(r.created_at) asc, s.id asc
  limit limit_count;
end;
$$;

revoke all on function public.scanlab_moderation_queue(integer)
  from public, anon, authenticated;
grant execute on function public.scanlab_moderation_queue(integer) to service_role;

create or replace function public.scanlab_moderate_scan(
  target uuid,
  decision text,
  note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  scan_row public.scanlab_scans%rowtype;
  normalized_decision text := lower(trim(decision));
  report_total integer;
  reasons jsonb;
  review_id bigint;
  reviewer_role text;
  was_auto_hidden boolean;
begin
  if target is null then
    raise exception 'moderation target required';
  end if;
  if normalized_decision not in ('approve', 'reject') then
    raise exception 'invalid moderation decision';
  end if;
  if note is null or char_length(note) > 1000 then
    raise exception 'invalid moderation note';
  end if;

  select * into scan_row
  from public.scanlab_scans
  where id = target
  for update;

  if not found then
    raise exception 'moderation target not found';
  end if;
  if scan_row.moderation_status = 'rejected' then
    raise exception 'moderation target already rejected';
  end if;

  select count(*)::integer into report_total
  from public.scanlab_reports
  where scan_id = target;

  if report_total < 1 then
    raise exception 'moderation target has no active reports';
  end if;

  select coalesce(pg_catalog.jsonb_object_agg(reason_group.reason, reason_group.reason_count), '{}'::jsonb)
    into reasons
  from (
    select reason, count(*)::bigint as reason_count
    from public.scanlab_reports
    where scan_id = target
    group by reason
  ) reason_group;

  begin
    reviewer_role := nullif(
      current_setting('request.jwt.claims', true)::jsonb ->> 'role',
      ''
    );
  exception when others then
    reviewer_role := null;
  end;
  reviewer_role := coalesce(reviewer_role, session_user::text);

  insert into scanlab_private.moderation_reviews (
    scan_id,
    decision,
    report_count,
    reason_counts,
    reviewer_role,
    note
  ) values (
    target,
    normalized_decision,
    report_total,
    reasons,
    reviewer_role,
    note
  ) returning id into review_id;

  if normalized_decision = 'approve' then
    insert into scanlab_private.report_dismissals (
      scan_id,
      reporter_id,
      dismissed_at,
      expires_at,
      review_id
    )
    select
      target,
      r.reporter_id,
      pg_catalog.now(),
      pg_catalog.now() + interval '30 days',
      review_id
    from public.scanlab_reports r
    where r.scan_id = target
    on conflict (scan_id, reporter_id) do update
      set dismissed_at = excluded.dismissed_at,
          expires_at = excluded.expires_at,
          review_id = excluded.review_id;

    delete from public.scanlab_reports where scan_id = target;

    was_auto_hidden := scan_row.status = 'hidden'
      and scan_row.moderation_status = 'pending';

    if was_auto_hidden then
      perform pg_catalog.set_config('scanlab.moderation_restore', '1', true);
      update public.scanlab_scans
         set status = 'published',
             moderation_status = 'approved',
             updated_at = pg_catalog.now()
       where id = target;
    elsif scan_row.moderation_status = 'pending' then
      update public.scanlab_scans
         set moderation_status = 'approved',
             updated_at = pg_catalog.now()
       where id = target;
    end if;
  else
    update public.scanlab_scans
       set status = 'hidden',
           moderation_status = 'rejected',
           updated_at = pg_catalog.now()
     where id = target;
  end if;

  return pg_catalog.jsonb_build_object(
    'scanId', target,
    'decision', normalized_decision,
    'reviewId', review_id,
    'reportCount', report_total,
    'restored', normalized_decision = 'approve' and was_auto_hidden
  );
end;
$$;

revoke all on function public.scanlab_moderate_scan(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.scanlab_moderate_scan(uuid, text, text) to service_role;
