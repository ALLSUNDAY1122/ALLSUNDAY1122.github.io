#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="AI引継ぎ帳"
EXPECTED_BUNDLE_ID="jp.allsunday.aihandoverlog"
EXPECTED_VERSION="0.6.0"
EXPECTED_BUILD="6"
SCHEME="Runner"
CONFIGURATION="Release"

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_DIR/testflight_release}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
OPEN_ORGANIZER=1
SKIP_TESTS=0
DRY_RUN=0

usage() {
  cat <<'EOF'
AI引継ぎ帳 v0.6 MacinCloud TestFlight Archive Tool

Usage:
  DEVELOPMENT_TEAM=XXXXXXXXXX ./macincloud_testflight_archive.sh [options]

Options:
  --project-dir PATH     Flutter project directory. Default: current directory
  --output-dir PATH      Output directory. Default: <project>/testflight_release
  --team-id ID           Apple Developer Team ID (or set DEVELOPMENT_TEAM)
  --skip-tests           Skip flutter analyze/test
  --no-open              Do not open the archive in Xcode at the end
  --dry-run              Print environment and planned values; do not build
  -h, --help             Show help

This script does not request or store Apple ID passwords, two-factor codes,
private keys, App Store Connect API keys, or app-specific passwords.
EOF
}

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --output-dir) OUTPUT_ROOT="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    --no-open) OPEN_ORGANIZER=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
OUTPUT_ROOT="$(mkdir -p "$OUTPUT_ROOT" && cd "$OUTPUT_ROOT" && pwd)"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE_PATH="$OUTPUT_ROOT/${APP_NAME// /_}_${EXPECTED_VERSION}_${EXPECTED_BUILD}_$TIMESTAMP.xcarchive"
LOG_DIR="$OUTPUT_ROOT/logs_$TIMESTAMP"
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_DIR/full.log") 2>&1

log "Preflight"
need sw_vers
need xcodebuild
need xcrun
need flutter
need plutil
need security
need /usr/libexec/PlistBuddy

[[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
[[ -f "$PROJECT_DIR/pubspec.yaml" ]] || die "pubspec.yaml not found in $PROJECT_DIR"
[[ -d "$PROJECT_DIR/ios/Runner.xcworkspace" ]] || die "ios/Runner.xcworkspace not found. Run flutter create . if needed."

MACOS_VERSION="$(sw_vers -productVersion)"
XCODE_VERSION="$(xcodebuild -version | head -n1)"
FLUTTER_VERSION="$(flutter --version | head -n1)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"

printf 'macOS: %s\nXcode: %s\niPhoneOS SDK: %s\nFlutter: %s\n' \
  "$MACOS_VERSION" "$XCODE_VERSION" "$SDK_VERSION" "$FLUTTER_VERSION"

XCODE_MAJOR="$(xcodebuild -version | awk '/Xcode/{split($2,a,"."); print a[1]}')"
[[ "$XCODE_MAJOR" =~ ^[0-9]+$ ]] || die "Could not determine Xcode major version."
(( XCODE_MAJOR >= 16 )) || die "Xcode 16 or later is required to build current iOS submissions."

if [[ -z "$TEAM_ID" ]]; then
  die "Apple Developer Team ID is required. Set DEVELOPMENT_TEAM or use --team-id."
fi
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID should be a 10-character Apple Team ID."

log "Configured values"
printf 'App: %s\nBundle ID: %s\nVersion: %s\nBuild: %s\nTeam ID: %s\nProject: %s\nArchive: %s\n' \
  "$APP_NAME" "$EXPECTED_BUNDLE_ID" "$EXPECTED_VERSION" "$EXPECTED_BUILD" \
  "$TEAM_ID" "$PROJECT_DIR" "$ARCHIVE_PATH"

if (( DRY_RUN == 1 )); then
  log "Dry run complete. No build was performed."
  exit 0
fi

cd "$PROJECT_DIR"

log "Check Xcode account and signing identities"
security find-identity -v -p codesigning | tee "$LOG_DIR/codesigning-identities.log" || true
IDENTITY_COUNT="$(security find-identity -v -p codesigning 2>/dev/null | grep -c '"Apple Distribution:' || true)"
if (( IDENTITY_COUNT == 0 )); then
  cat <<'EOF'
No local Apple Distribution identity was found.
Open Xcode > Settings > Accounts, sign in to the Apple Account, select the team,
and use Manage Certificates if Xcode does not create/download a distribution
certificate automatically. Then rerun this script.
EOF
  exit 2
fi

log "Flutter dependencies"
flutter clean
flutter pub get

if (( SKIP_TESTS == 0 )); then
  log "Static analysis"
  flutter analyze | tee "$LOG_DIR/flutter-analyze.log"

  log "Automated tests"
  flutter test | tee "$LOG_DIR/flutter-test.log"
fi

log "Resolve Xcode packages"
xcodebuild \
  -resolvePackageDependencies \
  -workspace ios/Runner.xcworkspace \
  -scheme "$SCHEME" \
  | tee "$LOG_DIR/xcode-resolve-packages.log"

log "Inspect effective Release settings"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -showBuildSettings \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$EXPECTED_BUNDLE_ID" \
  MARKETING_VERSION="$EXPECTED_VERSION" \
  CURRENT_PROJECT_VERSION="$EXPECTED_BUILD" \
  > "$LOG_DIR/build-settings.log"

grep -q "PRODUCT_BUNDLE_IDENTIFIER = $EXPECTED_BUNDLE_ID" "$LOG_DIR/build-settings.log" \
  || die "Effective Bundle ID does not match $EXPECTED_BUNDLE_ID"
grep -q "MARKETING_VERSION = $EXPECTED_VERSION" "$LOG_DIR/build-settings.log" \
  || die "Effective version does not match $EXPECTED_VERSION"
grep -q "CURRENT_PROJECT_VERSION = $EXPECTED_BUILD" "$LOG_DIR/build-settings.log" \
  || die "Effective build does not match $EXPECTED_BUILD"

log "Create signed App Store archive"
set -o pipefail
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$EXPECTED_BUNDLE_ID" \
  MARKETING_VERSION="$EXPECTED_VERSION" \
  CURRENT_PROJECT_VERSION="$EXPECTED_BUILD" \
  clean archive \
  | tee "$LOG_DIR/xcode-archive.log"

APP_PATH="$ARCHIVE_PATH/Products/Applications/Runner.app"
INFO_PLIST="$APP_PATH/Info.plist"
[[ -d "$ARCHIVE_PATH" ]] || die "Archive was not created."
[[ -d "$APP_PATH" ]] || die "Runner.app was not found in archive."
[[ -f "$INFO_PLIST" ]] || die "Info.plist was not found in archived app."

log "Validate archived metadata"
ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ACTUAL_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$INFO_PLIST" 2>/dev/null || true)"

[[ "$ACTUAL_BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || die "Archived Bundle ID mismatch: $ACTUAL_BUNDLE_ID"
[[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]] || die "Archived version mismatch: $ACTUAL_VERSION"
[[ "$ACTUAL_BUILD" == "$EXPECTED_BUILD" ]] || die "Archived build mismatch: $ACTUAL_BUILD"

codesign --verify --deep --strict --verbose=2 "$APP_PATH" \
  2>&1 | tee "$LOG_DIR/codesign-verify.log"

codesign -d --entitlements :- "$APP_PATH" \
  2> "$LOG_DIR/archived-entitlements.plist" || true

xcrun dwarfdump --uuid "$APP_PATH/Runner" \
  | tee "$LOG_DIR/binary-uuids.log"

cat > "$LOG_DIR/archive-summary.txt" <<EOF
App Name: $ACTUAL_NAME
Bundle ID: $ACTUAL_BUNDLE_ID
Version: $ACTUAL_VERSION
Build: $ACTUAL_BUILD
Team ID: $TEAM_ID
Archive: $ARCHIVE_PATH
Created: $(date -Iseconds)
EOF

log "Archive ready"
cat "$LOG_DIR/archive-summary.txt"

cat <<EOF

Next action in Xcode:
1. Open Window > Organizer > Archives.
2. Select this archive:
   $ARCHIVE_PATH
3. Click Validate App.
4. Fix every error before continuing.
5. Click Distribute App.
6. Choose TestFlight & App Store.
7. Keep automatic signing and symbol upload enabled.
8. Upload, then check App Store Connect > TestFlight > Build Uploads.

Do not upload the old unsigned archive.
EOF

if (( OPEN_ORGANIZER == 1 )); then
  open "$ARCHIVE_PATH" || true
fi
