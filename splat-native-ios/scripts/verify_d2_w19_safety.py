#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
base = root / 'supabase/migrations/20260815021337_scanlab_s7_ugc_safety_v7.sql'
hardening = root / 'supabase/migrations/20260817072000_scanlab_d2_w19_safety.sql'
errors=[]
for p in (base, hardening):
    if not p.exists(): errors.append(f'missing {p.relative_to(root)}')
if errors:
    print('\n'.join(errors)); sys.exit(1)
b=base.read_text(); h=hardening.read_text()
checks={
 'objectionable text guard remains': 'reject_objectionable_text' in b,
 'report abuse trigger': 'create trigger scanlab_report_abuse_guard before insert on public.scanlab_reports' in h,
 'report identity binding': "new.reporter_id <> (select auth.uid())" in h,
 'publish rate limit': "p_action='publish'" in h and 'max_count:=10' in h,
 'report rate limit': "p_action='report'" in h and 'max_count:=20' in h,
 'race serialization': 'pg_advisory_xact_lock' in h,
 'private-to-shared transition consumes quota': "old.visibility not in ('public','unlisted')" in h and 'entering_shared' in h,
 'owner moderation state protected': 'owner_moderation_state_guard' in h and 'owner cannot change moderation state' in h,
 'nested server moderation remains possible': 'pg_trigger_depth() = 1' in h,
 'abuse tables closed to clients': h.count('revoke all on public.scanlab_') >= 2,
 'moderation audit': 'scanlab_moderation_actions' in h and "'user report'" in h,
 'failure hint': "hint='retry later'" in h,
 'bounded retention': "interval '7 days'" in h,
}
for name,ok in checks.items():
    print(('PASS ' if ok else 'FAIL ')+name)
    if not ok: errors.append(name)
if errors: sys.exit(1)
print('D2-019 safety regression gate PASS')
