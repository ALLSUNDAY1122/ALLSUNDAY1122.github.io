#!/usr/bin/env python3
from pathlib import Path

p=Path('ios/health-manager-2/prepare-web-assets.sh')
text=p.read_text(encoding='utf-8')
old='''# Every Apple upload needs a unique CFBundleVersion. Codemagic officially
# exports BUILD_NUMBER per workflow; apply it before XcodeGen runs.
if [ -z "${BUILD_NUMBER:-}" ]; then
  echo "BUILD_NUMBER is required for release builds" >&2
  exit 1
fi
python3 - "$SCRIPT_DIR/project.yml" "$BUILD_NUMBER" <<'PY'
'''
new='''# Every Apple upload needs a unique CFBundleVersion. Older successful HM2
# builds exposed BUILD_NUMBER while other current Codemagic workflows use
# CM_BUILD_NUMBER. Accept either documented CI value but fail closed if neither
# exists; never silently fall back to a hard-coded build number.
RELEASE_BUILD_NUMBER="${BUILD_NUMBER:-${CM_BUILD_NUMBER:-}}"
if [ -z "$RELEASE_BUILD_NUMBER" ]; then
  echo "BUILD_NUMBER or CM_BUILD_NUMBER is required for release builds" >&2
  exit 1
fi
echo "PASS: HM2 release build number source resolved: $RELEASE_BUILD_NUMBER"
python3 - "$SCRIPT_DIR/project.yml" "$RELEASE_BUILD_NUMBER" <<'PY'
'''
if old not in text:
    raise SystemExit('Expected HM2 BUILD_NUMBER block not found; fail closed')
text=text.replace(old,new,1)
p.write_text(text,encoding='utf-8')
print('PASS: HM2 build-number environment resolution hardened')
