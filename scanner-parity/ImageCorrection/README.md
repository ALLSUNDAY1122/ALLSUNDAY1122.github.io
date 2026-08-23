# SCAN-002 Image Correction

## Scope

This module implements the worker-owned image-correction surface without changing the shared contract.

- Apple Vision rectangle detection for page-boundary candidates
- Core Image perspective correction
- portrait-orientation correction after geometry normalization
- three outputs: `archive`, `reading`, `ocr`
- luminance/shadow/highlight metrics for before/after comparison
- Otsu threshold calculation and preprocessing selection guardrails
- no dewarp auto-application until the book Golden Dataset establishes a measurable need

## Profile policy

### archive
The input image is preserved unchanged. Geometry observations are recorded in metadata, but perspective, rotation, tone and binary preprocessing are not destructively written to the archive image.

### reading
Perspective/rotation are applied when detected, then conservative highlight/shadow and contrast balancing is used. The goal is readability without turning a photographed book page into a harsh document scan.

### ocr
Perspective/rotation are applied, then grayscale, contrast and luminance sharpening are used. Hard Otsu binarization is deliberately not the default because thin Japanese strokes can be lost. `VariantSelector` requires a measurable score improvement over the original before a destructive preprocessing variant is selected.

## Dewarp policy

`dewarpApplied` remains `false` and `dewarpPendingGoldenEvaluation` is emitted. A dewarp implementation must not be enabled merely because curved-page correction is technically possible. Adopt it only if Golden pages show material text-line curvature/perspective residuals and the corrected output improves OCR/readability without cutting content.

## Fixture

Linux-compatible core test:

```bash
swiftc \
  scanner-parity/ImageCorrection/CorrectionCore.swift \
  scanner-parity/ImageCorrection/ApplePageCorrectionEngine.swift \
  scanner-parity/Tests/ImageCorrection/CorrectionCoreFixture.swift \
  -o /tmp/correction-fixture
/tmp/correction-fixture
```

Expected output:

```text
CorrectionCoreFixture PASS
```

The Apple Vision/Core Image implementation is conditionally compiled and therefore requires an Apple SDK target for framework-level type checking and runtime image tests. Linux fixture success must not be treated as iOS runtime or Golden Dataset PASS.

## Golden evaluation still required

For each representative page, record at minimum:

- boundary confidence and crop coverage
- residual skew and perspective severity
- source vs corrected mean luminance
- source vs corrected shadow/highlight fractions
- visible clipping or missing margins
- OCR/readability score for original vs reading vs OCR preprocessing
- whether dewarp provides a measurable gain

Do not promote aggressive preprocessing or dewarp when the gain is small or ambiguous.
