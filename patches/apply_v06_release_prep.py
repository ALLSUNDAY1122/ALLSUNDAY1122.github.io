#!/usr/bin/env python3
from pathlib import Path
import os
import sys

root = Path(sys.argv[1])
log_lines: list[str] = []


def note(message: str) -> None:
    print(message)
    log_lines.append(message)


def set_pubspec_version() -> None:
    path = root / 'pubspec.yaml'
    lines = path.read_text(encoding='utf-8').splitlines()
    found = False
    for index, line in enumerate(lines):
        if line.startswith('version:'):
            note(f'pubspec before: {line}')
            lines[index] = 'version: 0.6.0+6'
            found = True
            break
    if not found:
        lines.insert(1, 'version: 0.6.0+6')
        note('pubspec version line inserted')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def set_display_version(rel: str) -> None:
    path = root / rel
    text = path.read_text(encoding='utf-8')
    before = text.count('0.5.0') + text.count('0.4.0') + text.count('0.6.0')
    text = text.replace('0.5.0', '0.6.0').replace('0.4.0', '0.6.0')
    path.write_text(text, encoding='utf-8')
    note(f'{rel}: version markers before={before}, after={text.count("0.6.0")}')


set_pubspec_version()
set_display_version('lib/screens/settings_screen.dart')
set_display_version('test/widget_test.dart')

changelog = root / 'CHANGELOG.md'
if changelog.exists():
    text = changelog.read_text(encoding='utf-8')
    entry = '''## 0.6.0\n\n- iPhone実機向けReleaseビルドを署名なしで検証。\n- TestFlight提出用の署名・Archive・IPA作成手順を整備。\n- App Store Connect用Bundle ID、バージョン、Build番号を固定。\n- 輸出コンプライアンス設定を現行のオフライン実装に合わせて追加。\n\n'''
    if not text.startswith('## 0.6.0'):
        changelog.write_text(entry + text, encoding='utf-8')
        note('CHANGELOG v0.6 entry inserted')
    else:
        note('CHANGELOG v0.6 entry already present')

note('applied v0.6 release preparation')
runner_temp = os.environ.get('RUNNER_TEMP')
if runner_temp:
    log_path = Path(runner_temp) / 'logs' / 'v06-patch.log'
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text('\n'.join(log_lines) + '\n', encoding='utf-8')
