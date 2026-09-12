alter table public.scanlab_scans drop constraint if exists scanlab_no_publish_while_deleting;
alter table public.scanlab_scans add constraint scanlab_no_publish_while_deleting check (deletion_requested_at is null or status <> 'published');
