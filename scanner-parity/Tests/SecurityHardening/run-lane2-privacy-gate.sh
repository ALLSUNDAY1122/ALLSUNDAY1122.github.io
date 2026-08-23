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
        "/SecurityHardening/ApplePrivacyComplianceAuditor.swift"
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

echo "LANE2_PRIVACY_GATE=PASS"
