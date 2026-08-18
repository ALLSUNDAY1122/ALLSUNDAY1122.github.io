-- D2-015: trusted uploads must remain bound to a live owner draft that is not deleting.
-- This prevents a concurrent or stale client upload from recreating orphan assets after
-- delete cleanup has started or after the metadata row has already been removed.
create or replace function scanlab_private.is_trusted_upload_path(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when array_length(storage.foldername(object_name), 1) = 2
      and (storage.foldername(object_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and (storage.foldername(object_name))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and storage.filename(object_name) in ('scene.spz', 'manifest.json', 'preview.jpg', 'preview.png')
    then exists (
      select 1
      from public.scanlab_scans s
      where s.id = (storage.foldername(object_name))[2]::uuid
        and s.owner_id = (select auth.uid())
        and s.status = 'draft'
        and s.deletion_requested_at is null
        and storage.foldername(s.asset_path) = storage.foldername(object_name)
    )
    else false
  end
$$;

revoke all on function scanlab_private.is_trusted_upload_path(text) from public, anon;
grant execute on function scanlab_private.is_trusted_upload_path(text) to authenticated, service_role;
