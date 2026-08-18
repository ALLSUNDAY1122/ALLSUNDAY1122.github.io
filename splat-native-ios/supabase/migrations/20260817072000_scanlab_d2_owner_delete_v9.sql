-- D2-015: owner scan deletion must revoke publication before durable asset cleanup.
-- The Edge Function performs hide -> storage cleanup -> metadata delete. This guard prevents
-- direct authenticated DELETE from bypassing that recovery-safe sequence.

drop policy if exists "scanlab owner scan delete" on public.scanlab_scans;
revoke delete on public.scanlab_scans from authenticated;

-- Service-role Edge Functions retain backend deletion privileges; clients can only mutate
-- scans through the existing owner update policy and the dedicated delete function.
