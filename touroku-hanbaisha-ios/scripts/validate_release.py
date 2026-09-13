#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import plistlib
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "touroku-hanbaisha-ios"
NATIVE = IOS / "native-ios"
WEB = ROOT / "touroku-hanbaisha-sprint"
EXPECTED_BUNDLE = "com.allsunday1122.tourokuhanbaisha"
EXPECTED_APP_ID = "6802119268"
EXPECTED_TEAM = "MN3D2ZM44N"
EXPECTED_ICON_SHA = "c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03"
EXPECTED_WEB_URL = "https://allsunday1122.github.io/touroku-hanbaisha-sprint/"
EXPECTED_ORIENTATIONS = (
    "INFOPLIST_KEY_UISupportedInterfaceOrientations: \"UIInterfaceOrientationPortrait "
    "UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft "
    "UIInterfaceOrientationLandscapeRight\""
)
EXPECTED_EXPORT_COMPLIANCE = "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO"
EXPECTED_CHAPTER_COUNTS = {1: 20, 2: 20, 3: 40, 4: 20, 5: 20}

app = json.loads((IOS / "app.json").read_text(encoding="utf-8"))['expo']
assert app['version'] == '1.0.0'
assert app['ios']['bundleIdentifier'] == EXPECTED_BUNDLE
assert app['extra']['webAppUrl'] == EXPECTED_WEB_URL
assert app['ios']['icon'].endswith('AppIcon-1024.png')

project = (NATIVE / "project.yml").read_text(encoding="utf-8")
for token in (
    EXPECTED_BUNDLE,
    EXPECTED_TEAM,
    'MARKETING_VERSION: 1.0.0',
    'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon',
    EXPECTED_ORIENTATIONS,
    EXPECTED_EXPORT_COMPLIANCE,
):
    assert token in project, f'missing project setting: {token}'
assert '\n    resources:\n' not in project, 'XcodeGen target resources must be declared under sources'
for token in (
    '- path: Assets.xcassets\n        buildPhase: resources',
    '- path: PrivacyInfo.xcprivacy\n        buildPhase: resources',
):
    assert token in project, f'missing XcodeGen resource source: {token}'

icon = NATIVE / "Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
data = icon.read_bytes()
assert hashlib.sha256(data).hexdigest() == EXPECTED_ICON_SHA
assert data[:8] == b'\x89PNG\r\n\x1a\n'
w, h = struct.unpack('>II', data[16:24])
assert (w, h) == (1024, 1024)

with (NATIVE / "PrivacyInfo.xcprivacy").open('rb') as f:
    privacy = plistlib.load(f)
assert privacy.get('NSPrivacyTracking') is False
assert privacy.get('NSPrivacyCollectedDataTypes') == []

for name in ('index.html', 'history-calendar-v02.js', 'support.html', 'privacy.html', 'app-v07.js', 'r1-canonical-loader-v08.js'):
    assert (WEB / name).is_file(), f'missing web release input: {name}'
index = (WEB / 'index.html').read_text(encoding='utf-8')
history = (WEB / 'history-calendar-v02.js').read_text(encoding='utf-8')
learning = (WEB / 'app-v07.js').read_text(encoding='utf-8')
loader = (WEB / 'r1-canonical-loader-v08.js').read_text(encoding='utf-8')
assert 'history-calendar-v02.js' in index
for token in ('state?.inProgress', 'chapterAnswered', 'inProgress=true'):
    assert token in history, f'missing history-calendar behavior marker: {token}'

# Learning Acceptance Contract: the release must contain three independent
# 120-question rounds (360 total), not merely copy that claims 360 questions.
all_ids: set[str] = set()
question_total = 0
for round_no in (1, 2, 3):
    round_count = 0
    for chapter_no, expected_count in EXPECTED_CHAPTER_COUNTS.items():
        path = WEB / f'questions/exam-{round_no}/chapter-{chapter_no}.json'
        assert path.is_file(), f'missing question bank: {path.relative_to(ROOT)}'
        rows = json.loads(path.read_text(encoding='utf-8'))
        assert len(rows) == expected_count, (
            f'exam-{round_no}/chapter-{chapter_no}: {len(rows)}/{expected_count}'
        )
        round_count += len(rows)
        question_total += len(rows)
        for q in rows:
            qid = str(q.get('id') or '')
            assert qid and qid not in all_ids, f'duplicate/missing question id: {qid!r}'
            all_ids.add(qid)
            choices = q.get('choices')
            assert isinstance(choices, list) and len(choices) == 5, f'{qid}: choices != 5'
            assert len(set(map(str, choices))) == 5, f'{qid}: duplicate choices'
            answer = q.get('correct_index')
            assert isinstance(answer, int) and 0 <= answer < 5, f'{qid}: invalid correct_index'
            for field in ('question', 'topic', 'source_url', 'reference_date', 'rights_basis'):
                assert str(q.get(field) or '').strip(), f'{qid}: missing {field}'
            explanation = q.get('explanation') or q.get('point')
            assert str(explanation or '').strip(), f'{qid}: missing explanation/point'
            assert str(q['source_url']).startswith('https://'), f'{qid}: source must be HTTPS'
    assert round_count == 120, f'round {round_no}: {round_count}/120 questions'
assert question_total == 360 and len(all_ids) == 360, (question_total, len(all_ids))

# The app must support the complete human learning loop, not just question
# rendering: start -> understand feedback -> progress -> weak review -> retry,
# plus interruption/resume. These markers bind the shipped app logic to that
# Acceptance Contract and fail closed on accidental feature removal.
learning_contract = {
    'start': 'function startSession(',
    'progress persistence': 'function saveProgress()',
    'interruption resume': 'function resumeSession()',
    'quiz rendering': 'function renderQuiz()',
    'unknown answer path': 'data-dk',
    'understanding feedback': 'ここだけ覚える',
    'weak review': '苦手復習',
    'weak graduation': '3連続正解で解除',
    'result/progress': 'function renderResult()',
    'retry': 'data-again',
    'learning record': '学習記録',
}
for label, token in learning_contract.items():
    assert token in learning, f'learning acceptance missing {label}: {token}'
for token in (
    "loadRound(2)",
    "loadRound(3)",
    "const ALL_QUESTIONS=[...r1,...r2,...r3]",
    "validateRound(r1,1)",
    "validateRound(r2,2)",
    "validateRound(r3,3)",
):
    assert token in learning, f'360-question runtime contract missing: {token}'
assert 'rows.length!==120' in loader, 'R1 loader must fail closed unless 120 questions load'

metadata = (IOS / 'APP_STORE_METADATA.md').read_text(encoding='utf-8')
assert f'Bundle ID: {EXPECTED_BUNDLE}' in metadata
assert f'- サポート: {EXPECTED_WEB_URL}support.html' in metadata
assert f'- プライバシーポリシー: {EXPECTED_WEB_URL}privacy.html' in metadata

print(
    'PASS: Touhan release + learning acceptance; '
    f'bundle={EXPECTED_BUNDLE}; app_id={EXPECTED_APP_ID}; questions={question_total}; '
    f'icon_sha256={EXPECTED_ICON_SHA}; orientations=all-four; export_compliance=exempt; '
    'cycle=start-understand-progress-review-retry-resume'
)
