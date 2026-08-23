#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${TMPDIR:-/tmp}/scanner-parity-privacy-fixtures"
swiftc \
  "$ROOT/scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift" \
  "$ROOT/scanner-parity/Tests/PrivacyAudit/PrivacyStaticAuditorTests.swift" \
  -o "$OUT"
"$OUT"
