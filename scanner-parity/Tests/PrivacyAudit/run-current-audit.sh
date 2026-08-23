#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/main.swift" <<'SWIFT'
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let auditor = PrivacyStaticAuditor(extraAllowlist: ["xcrun", "swiftc"])
let report = try auditor.auditDirectory(root)
print(PrivacyStaticAuditor.markdown(report: report))
if !report.productionEgressRisks.isEmpty {
    exit(2)
}
SWIFT
swiftc "$ROOT/scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift" "$TMP/main.swift" -o "$TMP/privacy-audit"
"$TMP/privacy-audit" "$ROOT/scanner-parity"
