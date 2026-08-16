alter policy "scanlab storage owner insert"
on storage.objects
with check (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.scanlab_scans s
    where s.owner_id = (select auth.uid())
      and s.status = 'published'
      and storage.foldername(s.asset_path) = storage.foldername(name)
  )
);

alter policy "scanlab storage owner update"
on storage.objects
using (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.scanlab_scans s
    where s.owner_id = (select auth.uid())
      and s.status = 'published'
      and storage.foldername(s.asset_path) = storage.foldername(name)
  )
)
with check (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.scanlab_scans s
    where s.owner_id = (select auth.uid())
      and s.status = 'published'
      and storage.foldername(s.asset_path) = storage.foldername(name)
  )
);

alter policy "scanlab storage owner delete"
on storage.objects
using (
  bucket_id = 'scanlab-assets'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.scanlab_scans s
    where s.owner_id = (select auth.uid())
      and s.status = 'published'
      and storage.foldername(s.asset_path) = storage.foldername(name)
  )
);
