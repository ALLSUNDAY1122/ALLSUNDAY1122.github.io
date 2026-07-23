#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])


def regex_replace(rel: str, pattern: str, replacement: str) -> None:
    path = root / rel
    text = path.read_text(encoding='utf-8')
    changed, count = re.subn(
        pattern,
        replacement,
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit(f'v0.6 pattern not found in {rel}: {pattern!r}')
    path.write_text(changed, encoding='utf-8')


regex_replace('pubspec.yaml', r'^version:\s*0\.[45]\.0\+[45]\s*$', 'version: 0.6.0+6')
regex_replace(
    'lib/screens/settings_screen.dart',
    r'バージョン 0\.[45]\.0\\n端末内保存・オフライン設計',
    r'バージョン 0.6.0\\n端末内保存・オフライン設計',
)
regex_replace(
    'test/widget_test.dart',
    r'バージョン 0\.[45]\.0\\n端末内保存・オフライン設計',
    r'バージョン 0.6.0\\n端末内保存・オフライン設計',
)

changelog = root / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 0.6.0\n\n- iPhone実機向けReleaseビルドを署名なしで検証。\n- TestFlight提出用の署名・Archive・IPA作成手順を整備。\n- App Store Connect用Bundle ID、バージョン、Build番号を固定。\n- 輸出コンプライアンス設定を現行のオフライン実装に合わせて追加。\n\n'''
if not text.startswith('## 0.6.0'):
    changelog.write_text(entry + text, encoding='utf-8')
print('applied v0.6 release preparation')
