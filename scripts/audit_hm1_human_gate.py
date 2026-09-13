#!/usr/bin/env python3
"""Regression gate: App Store final submission must remain behind fresh human approval."""
from pathlib import Path

workflow = Path('.github/workflows/app2-005-hm1-submit-review.yml').read_text(encoding='utf-8')
submitter = Path('scripts/app2_005_hm1_prepare_submit.py').read_text(encoding='utf-8')
adapter = Path('scripts/app2_005_hm1_submit_from_approval.py').read_text(encoding='utf-8')
command = Path('automation/app2-005-hm1-submit-command.json').read_text(encoding='utf-8')

errors=[]
required_workflow=(
    'Require fresh explicit human approval for this exact release commit',
    "cmd.get('approved_by_user') is not True",
    "cmd.get('approved_commit')",
    'timedelta(hours=24)',
    "git','rev-parse','HEAD^",
    "approved_build=str(cmd.get('build') or '').strip()",
    'approved build must be a numeric App Store build version',
    'scripts/app2_005_hm1_submit_from_approval.py',
    '--command automation/app2-005-hm1-submit-command.json',
)
for marker in required_workflow:
    if marker not in workflow:
        errors.append(f'missing fail-closed approval marker: {marker}')

# Manual workflow_dispatch would bypass the approval-command push event semantics.
header=workflow.split('jobs:',1)[0]
if 'workflow_dispatch:' in header:
    errors.append('submission workflow must not expose manual workflow_dispatch')

# The approval adapter must be the single source of the submitted build.
required_adapter=(
    "cmd.get(\"approved_by_user\") is not True",
    'approved build must be a numeric App Store build version',
    'submitter.BUILD_VERSION = approved_build',
    'submitter.main()',
)
for marker in required_adapter:
    if marker not in adapter:
        errors.append(f'missing approval-build adapter marker: {marker}')
if '2026082501' in workflow:
    errors.append('submission workflow must not hard-code a historical build number')

# The submission implementation is intentionally dangerous; ensure the regression gate knows it really submits.
for marker in ('attributes={"submitted":True}', 'ensure_submission(token)', 'select_build(token, version_id)'):
    if marker not in submitter:
        errors.append(f'submitter behavior changed; re-review Human Gate: {marker}')

# Historical approvals are not accepted just because the command still says approved=true.
if '"approved_by_user": true' in command and '"approved_commit"' not in command:
    # Expected current condition: stale command remains inert because workflow requires approved_commit.
    pass

if errors:
    print('FAIL: HM1 App Review Human Gate regression')
    for e in errors:
        print('-',e)
    raise SystemExit(1)
print('PASS: HM1 App Review submission is fail-closed behind fresh commit-pinned approval and approval-pinned build')
