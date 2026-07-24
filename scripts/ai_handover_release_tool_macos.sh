#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<'EOF'
AI引継ぎ帳 v0.6 リリースツール統合入口

Usage:
  ./ai_handover_release_tool_macos.sh <command> [arguments...]

Commands:
  csr
    Apple Distribution用の暗号化秘密鍵とCSRを作成。
    Delegates to: generate_apple_distribution_csr_macos.sh

  p12
    Appleから取得した.cerとCSR秘密鍵を照合し、.p12を作成。
    Delegates to: build_apple_distribution_p12_macos.sh

  verify-offline
    .p12、App Store profile、API .p8をファイル構造だけで検証。
    Appleへ接続しない。
    Delegates to: verify_apple_signing_assets_macos.sh

  verify-online
    署名資産を検証し、App Store Connect API認証も確認。
    AppleのAPIへ接続する。
    Delegates to: validate_apple_release_credentials_macos.sh

  configure-github
    合格済みの署名資産をGitHub Environment secretsへ登録。
    Delegates to: configure_github_testflight_environment_macos.sh

  archive
    MacinCloud上でiPhone専用の署名Archiveを作成し事前検査。
    Delegates to: macincloud_testflight_submission.sh

  help
    このヘルプを表示。

Examples:
  ./ai_handover_release_tool_macos.sh csr \
    --email apple-account@example.com

  ./ai_handover_release_tool_macos.sh p12 \
    --private-key /secure/AppleDistribution.key.pem \
    --certificate ~/Downloads/distribution.cer

  ./ai_handover_release_tool_macos.sh verify-offline \
    --p12 /secure/AppleDistribution.p12 \
    --profile ~/Downloads/AppStore.mobileprovision \
    --api-key /secure/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id XXXXXXXXXX \
    --issuer-id 00000000-0000-0000-0000-000000000000

  ./ai_handover_release_tool_macos.sh verify-online \
    --certificate /secure/AppleDistribution.p12 \
    --profile ~/Downloads/AppStore.mobileprovision \
    --api-key /secure/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id XXXXXXXXXX \
    --issuer-id 00000000-0000-0000-0000-000000000000

  DEVELOPMENT_TEAM=ABCDEFGHIJ \
    ./ai_handover_release_tool_macos.sh archive \
    --project-dir "/Users/user/Projects/AI_Handover_Log_Flutter_v0.6"

Security:
- Do not paste Apple Account passwords, 2FA codes, private keys, .p12 files,
  provisioning profiles, .p8 contents, or GitHub secrets into ChatGPT,
  GitHub issues/PR comments, Notion, email, or shared folders.
- This dispatcher contains no credentials and stores no credentials.
EOF
}

require_script() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "ERROR: required script not found: $path" >&2
    exit 1
  }
  [[ -x "$path" ]] || chmod +x "$path"
}

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "ERROR: run this tool on macOS/MacinCloud." >&2
  exit 1
}

COMMAND="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$COMMAND" in
  csr)
    TARGET="$SCRIPT_DIR/generate_apple_distribution_csr_macos.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  p12)
    TARGET="$SCRIPT_DIR/build_apple_distribution_p12_macos.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  verify-offline)
    TARGET="$SCRIPT_DIR/verify_apple_signing_assets_macos.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  verify-online)
    TARGET="$SCRIPT_DIR/validate_apple_release_credentials_macos.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  configure-github)
    TARGET="$SCRIPT_DIR/configure_github_testflight_environment_macos.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  archive)
    TARGET="$SCRIPT_DIR/macincloud_testflight_submission.sh"
    require_script "$TARGET"
    exec "$TARGET" "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "ERROR: unknown command: $COMMAND" >&2
    usage >&2
    exit 1
    ;;
esac
