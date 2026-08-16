-- D2 W05: public publishing must not force a geotag.
-- A public scan may be Discover-only with no coordinates. If coordinates are attached,
-- both coordinates and the public-place attestation are required before it can be published.
-- Privacy/rights/content protections remain mandatory.

alter table public.scanlab_scans
  drop constraint if exists scanlab_public_requires_location_and_attestation;

alter table public.scanlab_scans
  drop constraint if exists scanlab_public_safety_attestation;

alter table public.scanlab_scans
  add constraint scanlab_public_safety_attestation
  check (
    visibility <> 'public'
    or status <> 'published'
    or (
      privacy_confirmed
      and rights_confirmed
      and (
        (latitude is null and longitude is null)
        or (
          latitude is not null
          and longitude is not null
          and public_place_confirmed
        )
      )
    )
  );

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
