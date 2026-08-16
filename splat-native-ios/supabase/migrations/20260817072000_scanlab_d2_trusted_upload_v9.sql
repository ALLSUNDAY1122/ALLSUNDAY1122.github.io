-- D2-004: trusted upload entry / authorization / validation
-- Fail closed at the storage boundary: authenticated owners may upload only the
-- C2 browser-share package files under <uid>/<scan-uuid>/{scene.spz,manifest.json,preview.jpg|png}.

create or replace function scanlab_private.is_trusted_upload_path(object_name text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    array_length(storage.foldername(object_name), 1) = 2
    and (storage.foldername(object_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    and (storage.foldername(object_name))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    and storage.filename(object_name) in ('scene.spz', 'manifest.json', 'preview.jpg', 'preview.png')
$$;

revoke all on function scanlab_private.is_trusted_upload_path(text) from public, anon, authenticated;

drop policy if exists "scanlab storage owner insert" on storage.objects;
drop policy if exists "scanlab storage owner update" on storage.objects;

create policy "scanlab storage trusted owner insert" on storage.objects
for insert to authenticated with check (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and scanlab_private.is_trusted_upload_path(name)
  and (
    (storage.filename(name) = 'scene.spz' and metadata->>'mimetype' = 'application/octet-stream')
    or (storage.filename(name) = 'manifest.json' and metadata->>'mimetype' in ('application/json', 'application/octet-stream'))
    or (storage.filename(name) = 'preview.jpg' and metadata->>'mimetype' = 'image/jpeg')
    or (storage.filename(name) = 'preview.png' and metadata->>'mimetype' = 'image/png')
  )
);

create policy "scanlab storage trusted owner update" on storage.objects
for update to authenticated using (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and scanlab_private.is_trusted_upload_path(name)
) with check (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and scanlab_private.is_trusted_upload_path(name)
  and (
    (storage.filename(name) = 'scene.spz' and metadata->>'mimetype' = 'application/octet-stream')
    or (storage.filename(name) = 'manifest.json' and metadata->>'mimetype' in ('application/json', 'application/octet-stream'))
    or (storage.filename(name) = 'preview.jpg' and metadata->>'mimetype' = 'image/jpeg')
    or (storage.filename(name) = 'preview.png' and metadata->>'mimetype' = 'image/png')
  )
);

-- A scan row may only point at its own trusted scene path. This prevents an
-- authenticated owner from publishing arbitrary objects in their bucket tree.
create or replace function scanlab_private.trusted_scan_asset_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parts text[];
begin
  parts := storage.foldername(new.asset_path);
  if array_length(parts, 1) <> 2
     or parts[1] <> new.owner_id::text
     or parts[2] <> new.id::text
     or storage.filename(new.asset_path) <> 'scene.spz'
     or not scanlab_private.is_trusted_upload_path(new.asset_path) then
    raise exception 'trusted upload path required';
  end if;
  if new.preview_path is not null and (
       array_length(storage.foldername(new.preview_path), 1) <> 2
       or (storage.foldername(new.preview_path))[1] <> new.owner_id::text
       or (storage.foldername(new.preview_path))[2] <> new.id::text
       or storage.filename(new.preview_path) not in ('preview.jpg', 'preview.png')
       or not scanlab_private.is_trusted_upload_path(new.preview_path)
  ) then
    raise exception 'trusted preview path required';
  end if;
  return new;
end;
$$;
revoke all on function scanlab_private.trusted_scan_asset_guard() from public, anon, authenticated;

drop trigger if exists scanlab_trusted_asset_guard on public.scanlab_scans;
create trigger scanlab_trusted_asset_guard
before insert or update of owner_id, asset_path, preview_path on public.scanlab_scans
for each row execute function scanlab_private.trusted_scan_asset_guard();
