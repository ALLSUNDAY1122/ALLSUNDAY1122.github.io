-- D2-018 regression gate: block/unblock visibility + interaction suppression.
-- Read-only assertions; run against the linked Scan Lab Supabase project.

do $$
declare
  public_scan_def text;
  reportable_def text;
  public_select_count integer;
begin
  public_scan_def := pg_get_functiondef('scanlab_private.is_public_scan(uuid)'::regprocedure);
  reportable_def := pg_get_functiondef('scanlab_private.is_reportable_scan(uuid)'::regprocedure);

  if position('scanlab_blocks' in public_scan_def) = 0
     or position('blocker_id = viewer.uid' in public_scan_def) = 0
     or position('blocked_id = viewer.uid' in public_scan_def) = 0 then
    raise exception 'D2-018 FAIL: like/public interaction guard is not bidirectional';
  end if;

  if position('scanlab_blocks' in reportable_def) = 0
     or position('blocker_id = (select auth.uid())' in reportable_def) = 0
     or position('blocked_id = (select auth.uid())' in reportable_def) = 0 then
    raise exception 'D2-018 FAIL: report guard is not bidirectional';
  end if;

  if position('report_dismissals' in reportable_def) = 0 then
    raise exception 'D2-018 FAIL: report dismissal contract was lost';
  end if;

  select count(*) into public_select_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'scanlab_scans'
    and policyname = 'scanlab public scans readable';

  if public_select_count <> 0 then
    raise exception 'D2-018 FAIL: direct public scan SELECT policy was reopened';
  end if;
end $$;
