# Privacy Static Audit

SCAN-011 provides a reproducible static audit for the scanner-parity production tree. It is evidence for the HQ Release Gate, not the final Privacy PASS/FAIL decision.

## Classification

- `egressRisk`: network APIs, network CLI, analytics SDKs, external-AI endpoints/SDK markers, and custom denylist entries. These rules cannot be disabled by the allowlist.
- `review`: local `Process`/CLI use and remote package declarations. These require inspection but do not by themselves mean book data leaves the device.
- `info`: Apple local-processing frameworks such as Vision, CoreImage, AVFoundation, PDFKit/CoreGraphics-related paths.

Tests are excluded from the production scan to prevent intentional denylist fixtures from becoming false production findings. Shell scripts are scanned so a future `curl`/`wget` path is not silently missed.

## Reproduce

```bash
scanner-parity/Tests/PrivacyAudit/run-fixtures.sh
scanner-parity/Tests/PrivacyAudit/run-current-audit.sh
```

`run-current-audit.sh` exits non-zero when a production `egressRisk` finding is present. Local build tooling (`xcrun`, `swiftc`) is allowlisted only as a review finding; allowlisting cannot suppress network/external-AI/analytics egress rules.

## Current sensitive paths reviewed

At integration baseline `45e420e9befb52ccb1b26837f3c7fd41078701c3`:

- Frame extraction: AVFoundation/CoreVideo/ImageIO; local video URL -> local candidate images/manifest.
- Page correction: CoreImage/Vision; local image processing.
- Page audit: Vision/ImageIO; local OCR-like recognition for page number/body evidence.
- Main OCR: Apple Vision (`VNRecognizeTextRequest`) against local image URLs.
- Tesseract comparison: Foundation `Process` invokes `/usr/bin/tesseract`; classified as local CLI review, not network egress.
- Book package: FileManager/Data writes local page images, text, manifest and searchable PDF.
- OCRExport `Package.swift`: no external package dependencies.

No direct network, analytics, or external-AI transport path was observed in those production-sensitive paths during SCAN-011. This is not a proof against dynamic/indirect runtime behavior; HQ Release Gate remains responsible for final Privacy acceptance and may add entitlement, dependency-graph, or runtime network verification.
