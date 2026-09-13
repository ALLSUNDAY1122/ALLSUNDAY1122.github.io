#!/usr/bin/env python3
"""Fail closed if an active app can reach App Review without fresh explicit human approval."""
from pathlib import Path

checks = {
    '.github/workflows/app2-005-hm1-submit-review.yml': {
        'required': ['approved_commit', 'timedelta(hours=24)', 'Require fresh explicit human approval'],
        'forbidden_header': ['workflow_dispatch:'],
    },
    '.github/workflows/app2-004-yakuzaishi-submit-review.yml': {
        'required': ['approved_commit', 'timedelta(hours=24)', 'Require fresh explicit human approval'],
        'forbidden_header': ['workflow_dispatch:'],
    },
    '.github/workflows/app2-009-submit-review.yml': {
        'required': ['APPROVE_APP_REVIEW=YES', 'APPROVED_COMMIT=', 'approval must pin current release commit'],
        'forbidden_header': [],
    },
}
errors=[]
for path, rule in checks.items():
    text=Path(path).read_text(encoding='utf-8')
    header=text.split('jobs:',1)[0]
    for marker in rule['required']:
        if marker not in text: errors.append(f'{path}: missing {marker}')
    for marker in rule['forbidden_header']:
        if marker in header: errors.append(f'{path}: forbidden final-submit trigger {marker}')

# Every guarded path still invokes a real submitter; otherwise this audit could pass on a dead route.
submit_markers={
 '.github/workflows/app2-005-hm1-submit-review.yml':'app2_005_hm1_prepare_submit.py',
 '.github/workflows/app2-004-yakuzaishi-submit-review.yml':'app2_004_yakuzaishi_submit_review.py',
 '.github/workflows/app2-009-submit-review.yml':'app2_009_kangoshi_submit_review.py',
}
for path,marker in submit_markers.items():
    if marker not in Path(path).read_text(encoding='utf-8'): errors.append(f'{path}: submitter route changed; re-audit required')

if errors:
    print('FAIL: active App Review Human Gate regression')
    for e in errors: print('-',e)
    raise SystemExit(1)
print('PASS: HM1 / Pharmacist / Nurse final App Review paths require current explicit human approval')
