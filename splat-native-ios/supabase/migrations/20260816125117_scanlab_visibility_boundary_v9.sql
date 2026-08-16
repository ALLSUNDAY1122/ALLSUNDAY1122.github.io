-- D2-W03: public / unlisted / private visibility boundary.
-- Authenticated clients may create owner-scoped drafts and explicitly hide their own
-- published rows. Promotion to published/approved and changes to publish-critical
-- columns are reserved for the trusted service-role publish path.

revoke insert, update on table public.scanlab_scans from authenticated;

-- Remove any column-level privileges left by earlier hardening steps before rebuilding
-- the least-privilege client contract.
revoke insert (
  id, owner_id, title, caption, visibility, status, moderation_status,
  share_token, asset_path, preview_path, latitude, longitude, location_label,
  public_place_confirmed, privacy_confirmed, rights_confirmed, published_at,
  created_at, updated_at, content_confirmed
) on table public.scanlab_scans from authenticated;

revoke update (
  id, owner_id, title, caption, visibility, status, moderation_status,
  share_token, asset_path, preview_path, latitude, longitude, location_label,
  public_place_confirmed, privacy_confirmed, rights_confirmed, published_at,
  created_at, updated_at, content_confirmed
) on table public.scanlab_scans from authenticated;

-- The iOS client inserts only a draft. Server-owned fields keep their defaults.
grant insert (
  owner_id, title, caption, visibility, status, asset_path, preview_path,
  latitude, longitude, location_label, public_place_confirmed,
  privacy_confirmed, rights_confirmed, content_confirmed
) on table public.scanlab_scans to authenticated;

-- The only direct owner mutation needed by the current client is explicit unpublish.
grant update (status) on table public.scanlab_scans to authenticated;

drop policy if exists "scanlab owner scan insert" on public.scanlab_scans;
create policy "scanlab owner scan insert" on public.scanlab_scans
for insert to authenticated
with check (
  (select auth.uid()) = owner_id
  and status = 'draft'
  and moderation_status = 'pending'
  and published_at is null
);

drop policy if exists "scanlab owner scan update" on public.scanlab_scans;
create policy "scanlab owner scan update" on public.scanlab_scans
for update to authenticated
using ((select auth.uid()) = owner_id)
with check (
  (select auth.uid()) = owner_id
  and status = 'hidden'
);

-- Migration-time regression gate: fail closed if a publish-critical client privilege
-- survives or the intended unpublish privilege is missing.
do $$
begin
  if has_table_privilege('authenticated', 'public.scanlab_scans', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated retains table UPDATE';
  end if;
  if has_column_privilege('authenticated', 'public.scanlab_scans', 'visibility', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated can UPDATE visibility';
  end if;
  if has_column_privilege('authenticated', 'public.scanlab_scans', 'asset_path', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated can UPDATE asset_path';
  end if;
  if has_column_privilege('authenticated', 'public.scanlab_scans', 'moderation_status', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated can UPDATE moderation_status';
  end if;
  if has_column_privilege('authenticated', 'public.scanlab_scans', 'published_at', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated can UPDATE published_at';
  end if;
  if not has_column_privilege('authenticated', 'public.scanlab_scans', 'status', 'UPDATE') then
    raise exception 'visibility gate failed: authenticated cannot unpublish via status';
  end if;
  if has_column_privilege('authenticated', 'public.scanlab_scans', 'moderation_status', 'INSERT') then
    raise exception 'visibility gate failed: authenticated can INSERT moderation_status';
  end if;
  if not has_column_privilege('authenticated', 'public.scanlab_scans', 'visibility', 'INSERT') then
    raise exception 'visibility gate failed: draft visibility INSERT missing';
  end if;
end;
$$;
