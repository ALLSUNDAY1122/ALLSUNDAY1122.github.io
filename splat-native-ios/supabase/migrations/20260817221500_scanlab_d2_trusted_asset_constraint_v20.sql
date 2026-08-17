-- D2-004: replace the frozen S7 `.splat` path constraint with the trusted C2
-- browser-share package contract used by D2.
alter table public.scanlab_scans drop constraint if exists scanlab_asset_owned_path;

alter table public.scanlab_scans
  add constraint scanlab_asset_owned_path
  check (asset_path = owner_id::text || '/' || id::text || '/scene.spz');

alter table public.scanlab_scans drop constraint if exists scanlab_preview_owned_path;
alter table public.scanlab_scans
  add constraint scanlab_preview_owned_path
  check (
    preview_path is null
    or preview_path = owner_id::text || '/' || id::text || '/preview.jpg'
    or preview_path = owner_id::text || '/' || id::text || '/preview.png'
  );
