create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entering_shared boolean := false;
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
    perform scanlab_private.consume_rate_limit(
      new.owner_id,
      'publish_shared',
      10,
      interval '1 hour'
    );
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
  requires_owner_republish boolean := false;
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

    requires_owner_republish := scan_row.status = 'hidden';

    if scan_row.moderation_status = 'pending' then
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
    'requiresOwnerRepublish', normalized_decision = 'approve' and requires_owner_republish
  );
end;
$$;

revoke all on function public.scanlab_moderate_scan(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.scanlab_moderate_scan(uuid, text, text) to service_role;
