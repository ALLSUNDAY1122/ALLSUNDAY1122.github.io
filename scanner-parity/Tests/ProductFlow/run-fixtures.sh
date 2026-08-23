#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${TMPDIR:-/tmp}/scanner-parity-product-flow-tests"
mkdir -p "$OUT_DIR"
SOURCES=("$ROOT"/ProductFlow/Sources/ProductFlow/*.swift)

swiftc "${SOURCES[@]}" "$ROOT/Tests/ProductFlow/ProductFlowStateTests.swift" -o "$OUT_DIR/state-tests"
"$OUT_DIR/state-tests"

swiftc "${SOURCES[@]}" "$ROOT/Tests/ProductFlow/ProductPipelineDriverTests.swift" -o "$OUT_DIR/pipeline-tests"
"$OUT_DIR/pipeline-tests"
