#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${TMPDIR:-/tmp}/scanner-parity-pipeline-core-tests"

swiftc \
  "$ROOT/scanner-parity/FrameExtraction/FrameExtractionModels.swift" \
  "$ROOT/scanner-parity/ImageCorrection/CorrectionCore.swift" \
  "$ROOT/scanner-parity/PageAudit/PageAuditModels.swift" \
  "$ROOT/scanner-parity/PageAudit/PageIntegrityAuditor.swift" \
  "$ROOT/scanner-parity/PipelineCore/PipelineAuditBridge.swift" \
  "$ROOT/scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift" \
  -o "$OUT"

"$OUT"
