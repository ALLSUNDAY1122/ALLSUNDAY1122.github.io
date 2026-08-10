#!/bin/bash
set -euo pipefail

APP_DIR="ios/App/App"
PLIST="$APP_DIR/Info.plist"
PROJECT="ios/App/App.xcodeproj/project.pbxproj"
BUILD_NUMBER="${CM_BUILD_NUMBER:-1}"

if [ ! -f "$PLIST" ] || [ ! -f "$PROJECT" ]; then
  echo "iOS project not generated. Run 'npx cap add ios' first." >&2
  exit 1
fi

cp PrivacyInfo.xcprivacy "$APP_DIR/PrivacyInfo.xcprivacy"
plutil -lint "$APP_DIR/PrivacyInfo.xcprivacy"

/usr/libexec/PlistBuddy -c "Delete :ITSAppUsesNonExemptEncryption" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"

# Initial release is iPhone-only. Golden Master is designed around a portrait,
# max-width 520px phone experience; iPad support can be added in a later version
# after a separate UI/screenshot audit.
perl -0pi -e 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/g' "$PROJECT"

# Version is fixed for the first release. Local/GitHub preflight defaults to
# build 1, while Codemagic injects its unique CM_BUILD_NUMBER.
perl -0pi -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = 1.0.0;/g' "$PROJECT"
perl -0pi -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PROJECT"

plutil -lint "$PLIST"
grep -q 'ITSAppUsesNonExemptEncryption' "$PLIST"
grep -q 'TARGETED_DEVICE_FAMILY = 1;' "$PROJECT"
grep -q 'MARKETING_VERSION = 1.0.0;' "$PROJECT"
grep -q "CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};" "$PROJECT"

echo "Configured iOS target: privacy manifest, export compliance, iPhone-only, version 1.0.0 (${BUILD_NUMBER})."
