#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/scanner-parity-product-flow-tests"
swiftc "$ROOT/ProductFlow/Sources/ProductFlow/ProductFlowState.swift" "$ROOT/Tests/ProductFlow/ProductFlowStateTests.swift" -o "$OUT"
"$OUT"
