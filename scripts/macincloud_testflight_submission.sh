#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/testflight_release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS is required." >&2
  exit 1
fi

python3 "$SCRIPT_DIR/harden_v06_ios_submission.py" "$PROJECT_DIR"

PROJECT_DIR="$PROJECT_DIR" OUTPUT_ROOT="$OUTPUT_ROOT" \
  "$SCRIPT_DIR/macincloud_testflight_archive.sh" --no-open "$@"

ARCHIVE_PATH="$(find "$OUTPUT_ROOT" -maxdepth 1 -type d -name '*.xcarchive' -print0 | xargs -0 ls -td | head -n1)"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Runner.app"
INFO_PLIST="$APP_PATH/Info.plist"

[[ -f "$INFO_PLIST" ]] || { echo "ERROR: archived Info.plist not found" >&2; exit 1; }
[[ -f "$APP_PATH/PrivacyInfo.xcprivacy" ]] || { echo "ERROR: app PrivacyInfo.xcprivacy missing" >&2; exit 1; }

FAMILY_0="$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$INFO_PLIST" 2>/dev/null || true)"
FAMILY_1="$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:1' "$INFO_PLIST" 2>/dev/null || true)"
ORIENTATION_0="$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations:0' "$INFO_PLIST" 2>/dev/null || true)"
ORIENTATION_1="$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations:1' "$INFO_PLIST" 2>/dev/null || true)"

[[ "$FAMILY_0" == "1" && -z "$FAMILY_1" ]] || {
  echo "ERROR: archive is not iPhone-only (UIDeviceFamily must be [1])." >&2
  exit 1
}
[[ "$ORIENTATION_0" == "UIInterfaceOrientationPortrait" && -z "$ORIENTATION_1" ]] || {
  echo "ERROR: archive is not portrait-only." >&2
  exit 1
}

find "$APP_PATH" -name PrivacyInfo.xcprivacy -print -exec plutil -lint {} \;

cat <<EOF

SUBMISSION_PREFLIGHT_OK
Archive: $ARCHIVE_PATH
Device family: iPhone only
Orientation: Portrait only
App privacy manifest: present

Xcode Organizerで次を実行してください。
1. ArchiveをControl-clickし、Generate Privacy Reportを選択
2. Trackingなし・Collected Dataなしを確認
3. Validate App
4. Distribute App → TestFlight & App Store → Upload
EOF

open "$ARCHIVE_PATH"
