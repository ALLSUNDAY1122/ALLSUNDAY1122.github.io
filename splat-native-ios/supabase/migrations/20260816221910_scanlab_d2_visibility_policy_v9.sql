-- D2-007: make public / unlisted / private semantics explicit at the database boundary.
-- public: published + approved, discoverable and shareable by id.
-- unlisted: published + approved, excluded from discovery, shareable only by token.
-- private: owner-only and never allowed to enter the published state.

alter table public.scanlab_scans
  add constraint scanlab_private_never_published
  check (visibility <> 'private' or status <> 'published');

create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  recent_count integer;
begin
  if new.visibility = 'private' and new.status = 'published' then
    raise exception 'private scan cannot be published';
  end if;

  if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published' or old.visibility is distinct from new.visibility) then
    if new.visibility='public' and (new.latitude is null or new.longitude is null or not new.public_place_confirmed or not new.privacy_confirmed or not new.rights_confirmed) then
      raise exception 'public scan requires location and safety attestations';
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

-- A token is intentionally not exposed by RLS. The service-role public endpoint is the
-- only unlisted resolver and requires the opaque token. Direct anon/authenticated table
-- reads continue to expose public scans only; owners retain access to all their scans.
comment on column public.scanlab_scans.visibility is
  'public=discoverable/shareable by id; unlisted=token-only published access; private=owner-only and never published';
