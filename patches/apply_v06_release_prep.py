#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1])


def replace(rel: str, old: str, new: str) -> None:
    path = root / rel
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'v0.6 anchor not found in {rel}: {old!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.5.0+5', 'version: 0.6.0+6')
replace(
    'lib/screens/settings_screen.dart',
    'バージョン 0.5.0\\n端末内保存・オフライン設計',
    'バージョン 0.6.0\\n端末内保存・オフライン設計',
)
replace(
    'test/widget_test.dart',
    'バージョン 0.5.0\\n端末内保存・オフライン設計',
    'バージョン 0.6.0\\n端末内保存・オフライン設計',
)

changelog = root / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 0.6.0\n\n- iPhone実機向けReleaseビルドを署名なしで検証。\n- TestFlight提出用の署名・Archive・IPA作成手順を整備。\n- App Store Connect用Bundle ID、バージョン、Build番号を固定。\n- 輸出コンプライアンス設定を現行のオフライン実装に合わせて追加。\n\n'''
changelog.write_text(entry + text, encoding='utf-8')
print('applied v0.6 release preparation')
