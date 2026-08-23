#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc "$ROOT/scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift" \
  "$ROOT/scanner-parity/Tests/PrivacyAudit/PrivacyStaticAuditorTests.swift" \
  -o "$TMP/privacy-static-tests"
"$TMP/privacy-static-tests"

swiftc "$ROOT/scanner-parity/SecurityHardening/DataLifecyclePolicy.swift" \
  "$ROOT/scanner-parity/Tests/SecurityHardening/DataLifecyclePolicyTests.swift" \
  -o "$TMP/data-lifecycle-tests"
"$TMP/data-lifecycle-tests"

swiftc "$ROOT/scanner-parity/SecurityHardening/ApplePrivacyComplianceAuditor.swift" \
  "$ROOT/scanner-parity/Tests/SecurityHardening/ApplePrivacyComplianceAuditorTests.swift" \
  -o "$TMP/apple-privacy-tests"
"$TMP/apple-privacy-tests" "$ROOT/scanner-parity/SecurityHardening/PrivacyManifestBaseline.xcprivacy"

swiftc "$ROOT/scanner-parity/SecurityHardening/SensitiveDataStaticAudit.swift" \
  "$ROOT/scanner-parity/Tests/SecurityHardening/SensitiveDataStaticAuditTests.swift" \
  -o "$TMP/sensitive-data-tests"
"$TMP/sensitive-data-tests"

swiftc "$ROOT/scanner-parity/SecurityHardening/ProcessingStorageLifecycleAuditor.swift" \
  "$ROOT/scanner-parity/Tests/SecurityHardening/ProcessingStorageLifecycleAuditorTests.swift" \
  -o "$TMP/processing-storage-tests"
"$TMP/processing-storage-tests"

cat > "$TMP/current-audit.swift" <<'SWIFT'
import Foundation
@main struct CurrentAudit {
  static func main() throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let auditor = PrivacyStaticAuditor(
      extraAllowlist: ["xcrun", "swiftc"],
      excludedPathFragments: [
        "/Tests/",
        "/PrivacyAudit/PrivacyStaticAuditor.swift",
        "/SecurityHardening/SensitiveDataStaticAudit.swift",
        "/SecurityHardening/ApplePrivacyComplianceAuditor.swift",
        "/SecurityHardening/ProcessingStorageLifecycleAuditor.swift"
      ]
    )
    let report = try auditor.auditDirectory(root)
    print(PrivacyStaticAuditor.markdown(report: report))
    if !report.releaseBlockingFindings.isEmpty { exit(2) }
  }
}
SWIFT
swiftc "$ROOT/scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift" "$TMP/current-audit.swift" -o "$TMP/current-audit"
"$TMP/current-audit" "$ROOT/scanner-parity"

APP_SHELL="$ROOT/scanner-parity/AppShell"
if [[ -d "$APP_SHELL" ]]; then
  if ! find "$APP_SHELL" -type f -name 'PrivacyInfo.xcprivacy' -print -quit | grep -q .; then
    echo "PRIVACY_BLOCKER: AppShell has no bundled PrivacyInfo.xcprivacy" >&2
    exit 3
  fi

  MEDIA="$APP_SHELL/Sources/AppShell/MediaImportCoordinator.swift"
  STORE="$APP_SHELL/Sources/AppShell/ProductFlowStore.swift"
  RUNTIME="$APP_SHELL/Sources/AppShell/ProductionScannerRuntime.swift"
  if [[ -f "$MEDIA" && -f "$STORE" && -f "$RUNTIME" ]]; then
    cat > "$TMP/storage-audit.swift" <<'SWIFT'
import Foundation
@main struct StorageAuditRunner {
  static func main() throws {
    let args = CommandLine.arguments
    let media = try String(contentsOfFile: args[1], encoding: .utf8)
    let store = try String(contentsOfFile: args[2], encoding: .utf8)
    let runtime = try String(contentsOfFile: args[3], encoding: .utf8)
    var resources: [String] = []
    let root = URL(fileURLWithPath: args[4])
    if let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
      for case let u as URL in e where ["plist", "xcprivacy"].contains(u.pathExtension.lowercased()) {
        if let text = try? String(contentsOf: u, encoding: .utf8) { resources.append(text) }
      }
    }
    let report = ProcessingStorageLifecycleAuditor().audit(
      mediaImportSource: media,
      productFlowStoreSource: store,
      productionRuntimeSource: runtime,
      appResourceTexts: resources
    )
    if !report.pass {
      for issue in report.issues { fputs("PRIVACY_BLOCKER: \(issue.rawValue)\n", stderr) }
      exit(5)
    }
  }
}
SWIFT
    swiftc "$ROOT/scanner-parity/SecurityHardening/ProcessingStorageLifecycleAuditor.swift" "$TMP/storage-audit.swift" -o "$TMP/storage-audit"
    "$TMP/storage-audit" "$MEDIA" "$STORE" "$RUNTIME" "$APP_SHELL"
  fi
fi

echo "LANE2_PRIVACY_GATE=PASS"
