#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${TMPDIR:-/tmp}/scanner-parity-pipeline-ocr-tests"

swiftc \
  "$ROOT/scanner-parity/FrameExtraction/FrameExtractionModels.swift" \
  "$ROOT/scanner-parity/ImageCorrection/CorrectionCore.swift" \
  "$ROOT/scanner-parity/PageAudit/PageAuditModels.swift" \
  "$ROOT/scanner-parity/PageAudit/PageIntegrityAuditor.swift" \
  "$ROOT/scanner-parity/PipelineCore/PipelineAuditBridge.swift" \
  "$ROOT/scanner-parity/OCRExport/Sources/OCRExport/OCRModels.swift" \
  "$ROOT/scanner-parity/OCRExport/Sources/OCRExport/PageImageWriter.swift" \
  "$ROOT/scanner-parity/OCRExport/Sources/OCRExport/SearchablePDFWriter.swift" \
  "$ROOT/scanner-parity/OCRExport/Sources/OCRExport/BookPackageWriter.swift" \
  "$ROOT/scanner-parity/PipelineOCR/PipelineOCRBridge.swift" \
  "$ROOT/scanner-parity/Tests/PipelineOCR/PipelineOCRBridgeTests.swift" \
  -o "$OUT"

"$OUT"
