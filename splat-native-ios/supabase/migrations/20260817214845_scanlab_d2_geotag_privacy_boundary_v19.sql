create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  recent_count integer;
begin
  -- Location metadata is public-only. Changing away from public atomically scrubs
  -- coordinates, labels, and the public-place attestation before constraints run.
  if new.visibility <> 'public' then
    new.latitude := null;
    new.longitude := null;
    new.location_label := null;
    new.public_place_confirmed := false;
  else
    -- Public geotag is optional, but partial/stale location state is never valid.
    if (new.latitude is null) <> (new.longitude is null) then
      raise exception 'public geotag requires both latitude and longitude';
    end if;
    if new.latitude is null then
      new.location_label := null;
      new.public_place_confirmed := false;
    end if;
  end if;

  if new.visibility = 'private' then
    new.status := case when tg_op='UPDATE' and old.status='published' then 'hidden' else new.status end;
    if new.status = 'published' then
      raise exception 'private scan cannot be published';
    end if;
  end if;

  if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published' or old.visibility is distinct from new.visibility) then
    if new.visibility='public' then
      if not new.privacy_confirmed or not new.rights_confirmed then
        raise exception 'public scan requires privacy and rights attestations';
      end if;
      if new.latitude is not null and not new.public_place_confirmed then
        raise exception 'public geotag requires public-place attestation';
      end if;
    end if;
    if new.visibility in ('public','unlisted') then
      select count(*) into recent_count
      from public.scanlab_scans
      where owner_id=new.owner_id and status='published' and visibility in ('public','unlisted')
        and published_at > now() - interval '1 hour'
        and id <> new.id;
      if recent_count >= 10 then
        raise exception 'publish rate limit exceeded';
      end if;
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;

  if new.status <> 'published' then
    new.published_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists scanlab_scan_publish_guard on public.scanlab_scans;
create trigger scanlab_scan_publish_guard
before insert or update of status, visibility, latitude, longitude, location_label, public_place_confirmed
on public.scanlab_scans
for each row execute function scanlab_private.publish_guard();

alter table public.scanlab_scans
  add constraint scanlab_location_public_only
  check (
    visibility = 'public'
    or (
      latitude is null
      and longitude is null
      and location_label is null
      and public_place_confirmed = false
    )
  );

alter table public.scanlab_scans
  add constraint scanlab_geotag_pair_integrity
  check (
    (latitude is null and longitude is null and location_label is null and public_place_confirmed = false)
    or
    (latitude is not null and longitude is not null)
  );