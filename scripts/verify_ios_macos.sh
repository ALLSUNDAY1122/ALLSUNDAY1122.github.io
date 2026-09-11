#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f pubspec.yaml || ! -d ios || ! -d lib ]]; then
  echo "ERROR: Flutterプロジェクトのルートで実行してください。" >&2
  exit 1
fi

STAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="$ROOT_DIR/build_reports/ios_$STAMP"
mkdir -p "$REPORT_DIR"
LOG_FILE="$REPORT_DIR/verification.log"
exec > >(tee -a "$LOG_FILE") 2>&1

step() {
  printf '\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

step "1. Apple・Flutter環境確認"
sw_vers
xcode-select -p
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version
flutter --version
dart --version
pod --version

step "2. Flutter doctor"
flutter doctor -v | tee "$REPORT_DIR/flutter_doctor.log"

step "3. クリーンアップと依存解決"
flutter clean
flutter pub get | tee "$REPORT_DIR/pub_get.log"

step "4. コード整形検査"
dart format --output=none --set-exit-if-changed lib test | tee "$REPORT_DIR/format.log"

step "5. 静的解析"
flutter analyze | tee "$REPORT_DIR/analyze.log"

step "6. 自動テスト"
flutter test --coverage | tee "$REPORT_DIR/test.log"

step "7. iOSシミュレータービルド"
flutter build ios --simulator --debug | tee "$REPORT_DIR/ios_simulator_build.log"

APP_PATH="$ROOT_DIR/build/ios/iphonesimulator/Runner.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Runner.appが生成されませんでした。" >&2
  exit 1
fi

step "8. 生成アプリ検査"
echo "APP_PATH=$APP_PATH"
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP_PATH/Info.plist" | tee "$REPORT_DIR/display_name.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" | tee "$REPORT_DIR/bundle_identifier.txt"
/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP_PATH/Info.plist" | tee "$REPORT_DIR/minimum_ios.txt"
find "$APP_PATH/Frameworks" -maxdepth 1 -type d -print 2>/dev/null | sort | tee "$REPORT_DIR/frameworks.txt"
cp ios/Podfile.lock "$REPORT_DIR/Podfile.lock"

step "9. シミュレーターアプリ圧縮・SHA-256生成"
APP_ZIP="$REPORT_DIR/AI_Handover_Log_v0.4_iOS_Simulator_Runner.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
shasum -a 256 "$APP_ZIP" | tee "$REPORT_DIR/AI_Handover_Log_v0.4_iOS_Simulator_Runner.app.sha256"

cat > "$REPORT_DIR/RESULT.md" <<EOF
# AI引継ぎ帳 iOSシミュレーター検証結果

実行日時：$(date '+%Y-%m-%d %H:%M:%S %Z')

- Flutter依存解決：成功
- Dart整形検査：成功
- Flutter静的解析：成功
- Flutter自動テスト：成功
- CocoaPods連携：成功
- iOSシミュレータービルド：成功
- Runner.app生成：成功

## 生成物

- \`$APP_ZIP\`
- \`$REPORT_DIR/verification.log\`
- \`$REPORT_DIR/ios_simulator_build.log\`
- \`$REPORT_DIR/Podfile.lock\`

Apple署名、iPhone実機、Archive、TestFlightは別工程です。
EOF

step "検証完了"
echo "結果フォルダ: $REPORT_DIR"
echo "次はXcodeでRunner.xcworkspaceを開き、署名設定と実機確認を行います。"
