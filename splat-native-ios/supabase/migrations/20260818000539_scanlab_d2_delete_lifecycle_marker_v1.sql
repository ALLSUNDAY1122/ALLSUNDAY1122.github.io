alter table public.scanlab_scans add column if not exists deletion_requested_at timestamptz;
revoke update (deletion_requested_at) on public.scanlab_scans from authenticated;
comment on column public.scanlab_scans.deletion_requested_at is 'D2-015 durable owner-delete lifecycle marker; non-null blocks publish/republish until cleanup completes.';
