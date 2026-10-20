alter table public.scanlab_scans
  add constraint scanlab_asset_owned_path check (asset_path like owner_id::text || '/%' and asset_path like '%.splat'),
  add constraint scanlab_preview_owned_path check (preview_path is null or (preview_path like owner_id::text || '/%' and (preview_path like '%.jpg' or preview_path like '%.jpeg' or preview_path like '%.png')));
