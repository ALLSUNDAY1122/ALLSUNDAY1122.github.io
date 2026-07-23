#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1])


def replace_version(rel: str, new_value: str, old_values: tuple[str, ...]) -> None:
    path = root / rel
    text = path.read_text(encoding='utf-8')
    for old in old_values:
        if old in text:
            path.write_text(text.replace(old, new_value, 1), encoding='utf-8')
            print(f'{rel}: {old} -> {new_value}')
            return
    raise SystemExit(f'v0.6 version marker not found in {rel}')


replace_version(
    'pubspec.yaml',
    'version: 0.6.0+6',
    ('version: 0.5.0+5', 'version: 0.4.0+4'),
)
replace_version(
    'lib/screens/settings_screen.dart',
    'バージョン 0.6.0',
    ('バージョン 0.5.0', 'バージョン 0.4.0'),
)
replace_version(
    'test/widget_test.dart',
    'バージョン 0.6.0',
    ('バージョン 0.5.0', 'バージョン 0.4.0'),
)

changelog = root / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 0.6.0\n\n- iPhone実機向けReleaseビルドを署名なしで検証。\n- TestFlight提出用の署名・Archive・IPA作成手順を整備。\n- App Store Connect用Bundle ID、バージョン、Build番号を固定。\n- 輸出コンプライアンス設定を現行のオフライン実装に合わせて追加。\n\n'''
if not text.startswith('## 0.6.0'):
    changelog.write_text(entry + text, encoding='utf-8')
print('applied v0.6 release preparation')
