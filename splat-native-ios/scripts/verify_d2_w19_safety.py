#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
base = root / 'supabase/migrations/20260815021337_scanlab_s7_ugc_safety_v7.sql'
hardening = root / 'supabase/migrations/20260818084300_scanlab_d2_w19_safety.sql'
errors=[]
for p in (base, hardening):
    if not p.exists(): errors.append(f'missing {p.relative_to(root)}')
if errors:
    print('\n'.join(errors)); sys.exit(1)
b=base.read_text(); h=hardening.read_text()
checks={
 'objectionable text guard remains': 'reject_objectionable_text' in b,
 'report abuse guard available for histories without atomic quota': 'create trigger scanlab_report_abuse_guard before insert on public.scanlab_reports' in h,
 'existing report quota is not stacked': "tgname='scanlab_reports_rate_limit'" in h and 'if not exists' in h,
 'report identity binding': "new.reporter_id <> (select auth.uid())" in h,
 'publish fallback rate limit': "p_action='publish'" in h and 'max_count:=10' in h,
 'report fallback rate limit': "p_action='report'" in h and 'max_count:=20' in h,
 'race serialization': 'pg_advisory_xact_lock' in h,
 'existing publish token bucket reused': "consume_rate_limit(uuid,text,integer,interval)" in h and "'publish_shared'" in h and 'to_regprocedure' in h,
 'private-to-shared transition consumes quota': "old.visibility not in ('public','unlisted')" in h and 'entering_shared' in h,
 'owner moderation state protected': 'owner_moderation_state_guard' in h and 'owner cannot change moderation state' in h,
 'nested server moderation remains possible': 'pg_trigger_depth() = 1' in h,
 'abuse tables closed to clients': h.count('revoke all on public.scanlab_') >= 2,
 'three-distinct-report moderation threshold preserved': 'count(distinct reporter_id)' in h and 'report_count >= 3' in h and "interval '30 days'" in h,
 'single report does not directly hide': "'3 distinct user reports'" in h,
 'moderation audit': 'scanlab_moderation_actions' in h and "'3 distinct user reports'" in h,
 'failure hint': "hint='retry later'" in h,
 'bounded retention': "interval '7 days'" in h,
}
for name,ok in checks.items():
    print(('PASS ' if ok else 'FAIL ')+name)
    if not ok: errors.append(name)
if errors: sys.exit(1)
print('D2-019 safety regression gate PASS')
