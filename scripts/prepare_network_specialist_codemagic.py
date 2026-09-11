#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'codemagic.yaml'
text = path.read_text(encoding='utf-8')
marker = '\n  network-specialist-native-ios:\n'
if marker not in text:
    raise SystemExit('network-specialist-native-ios workflow missing')

start = text.index(marker)
search_from = start + len(marker)
next_match = re.search(r'(?m)^  [A-Za-z0-9][A-Za-z0-9_.-]*:\s*$', text[search_from:])
end = search_from + next_match.start() if next_match else len(text)
block = text[start:end]

src_line = "          SRC='network-specialist-sprint/07_ネットワークスペシャリスト試験.png'\n"
if src_line in block:
    print('network-specialist-native-ios canonical AppIcon transport already repaired')
    raise SystemExit(0)

old_start_line = "          DEST='network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'\n"
resume_line = '          python3 network-specialist-sprint/scripts/build_native_questions.py\n'
rel_start = block.find(old_start_line)
rel_resume = block.find(resume_line, rel_start)
if rel_start < 0 or rel_resume < 0:
    raise SystemExit('expected network-specialist AppIcon transport block not found')

replacement = (
    src_line
    + old_start_line
    + '          test -f "$SRC"\n'
    + '          test "$(stat -f%z "$SRC")" = \'678310\'\n'
    + '          test "$(shasum -a 256 "$SRC" | awk \'{print $1}\')" = "$APPICON_SHA256"\n'
    + '          mkdir -p "$(dirname "$DEST")"\n'
    + '          cp "$SRC" "$DEST"\n'
)

abs_start = start + rel_start
abs_resume = start + rel_resume
text = text[:abs_start] + replacement + text[abs_resume:]
path.write_text(text, encoding='utf-8')
print('repaired network-specialist-native-ios canonical AppIcon transport to repository source')
