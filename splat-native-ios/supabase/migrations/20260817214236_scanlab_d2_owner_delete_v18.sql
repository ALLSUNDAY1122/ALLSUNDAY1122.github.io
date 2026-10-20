-- D2-015: owner scan deletion must revoke publication before durable asset cleanup.
drop policy if exists "scanlab owner scan delete" on public.scanlab_scans;
revoke delete on public.scanlab_scans from authenticated;
