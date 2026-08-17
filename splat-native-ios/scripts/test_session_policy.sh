#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if grep -q '@testable import SplatNative' "$root/SplatNativeTests/ScanLabSessionPolicyTests.swift"; then
    echo 'session-policy regression failed: tests compile policy source directly and must not import SplatNative' >&2
    exit 1
fi

cp "$root/SplatNative/ScanLabSessionPolicy.swift" "$tmp/ScanLabSessionPolicy.swift"
cat > "$tmp/main.swift" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("session-policy regression failed: \(message)\n", stderr)
        exit(1)
    }
}

let validRestore = ScanLabSessionEvent.initialSession(hasSession: true, isExpired: false)
expect(ScanLabSessionPolicy.isAuthenticated(after: validRestore), "valid persisted session must authenticate")
expect(ScanLabSessionPolicy.shouldReloadPrivateData(after: validRestore), "valid persisted session must reload private data")
expect(!ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: validRestore), "valid persisted session must not wait for refresh")

let expiredRestore = ScanLabSessionEvent.initialSession(hasSession: true, isExpired: true)
expect(ScanLabSessionPolicy.isAuthenticated(after: expiredRestore), "expired persisted session should keep restored auth context while refresh runs")
expect(!ScanLabSessionPolicy.shouldReloadPrivateData(after: expiredRestore), "expired persisted session must not access private data before refresh")
expect(ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: expiredRestore), "expired persisted session must wait for refresh")

expect(ScanLabSessionPolicy.isAuthenticated(after: .tokenRefreshed), "token refresh must keep auth state")
expect(!ScanLabSessionPolicy.shouldReloadPrivateData(after: .tokenRefreshed), "periodic token refresh must not trigger reload storm")
expect(!ScanLabSessionPolicy.isAuthenticated(after: .signedOut), "signed out must clear auth state")
expect(ScanLabSessionPolicy.recoveryDecision(hasCachedSessionAfterFailure: true) == .keepAuthenticatedAndRetry, "transient refresh failure with cached session must remain retryable")
expect(ScanLabSessionPolicy.recoveryDecision(hasCachedSessionAfterFailure: false) == .requireSignIn, "lost session must require sign-in")

print("session-policy regression gate passed")
SWIFT

xcrun swiftc "$tmp/ScanLabSessionPolicy.swift" "$tmp/main.swift" -o "$tmp/session-policy-gate"
"$tmp/session-policy-gate"
