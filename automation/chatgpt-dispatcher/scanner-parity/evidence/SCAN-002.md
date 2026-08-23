# SCAN-002 Evidence｜Image Correction

Timestamp: 2026-08-23 13:41 JST
Worker: `worker4`
Claim: `8ebb84e2-20fa-4f3f-b2d5-446a2aec8589`
Claim epoch: `1`
Attempt branch: `task/SCAN-002/attempt-1`
Baseline: `99a8d30f2a09c85119869feabae9b411a3431133`

## Source-of-truth audit

Read before implementation:

- Notion `AIアプリ開発・公開フロー v2.7`
- Notion `申請手順`
- Notion `分割セッション手順 v1.1`
- Notion `書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本`
- GitHub Worker contract / Shared contract / migration handoff
- internal asset `いっしょに一冊（仮）｜10冊版iOS実装・PDFスキャナー v0.7`
- internal asset `撮る単語帳｜正本・関連資料`
- `撮る単語帳｜Safari価値検証 v0.2・OCR改善`
- `toru-tango-mobile/modules/toru-tango-ocr/ios/ToruTangoOcrModule.swift`

Integration baseline compare was `identical`: current `scanner-parity/integration` matched the Queue baseline SHA before claim.

## Reuse / license decision

### Adopted
- Apple Vision rectangle detection (`VNDetectRectanglesRequest`)
- Apple Core Image perspective/tone processing
- internal design principle from `いっしょに一冊`: automatic boundary + perspective correction while retaining the source image
- internal design principle from `撮る単語帳`: compare preprocessing variants and do not accept a transformed image merely because transformation is available

### Not adopted in this attempt
- OpenCV or third-party document-scanner code: not required for the first engine slice; therefore no third-party code/license/NOTICE was introduced
- hard Otsu binarization as the default OCR image: thin Japanese strokes may be destroyed; the threshold utility is implemented but default adoption is gated by measured score improvement
- Safari histogram/thin-text transforms: not blindly copied because the current canonical Golden book pages are unavailable for a same-page comparison
- dewarp: implementation intentionally deferred until Golden pages demonstrate a material curvature problem and measurable benefit

## Implementation

Added inside SCAN-002 write scope:

- `scanner-parity/ImageCorrection/CorrectionCore.swift`
  - normalized page quadrilateral and plausibility checks
  - page area / residual skew / perspective-severity metrics
  - source/corrected luminance metrics including shadow and highlight fractions
  - Otsu threshold calculation
  - preprocessing-variant selection guardrail requiring meaningful gain over original
  - archive / reading / OCR profile metadata compatible with the Shared Contract concepts
- `scanner-parity/ImageCorrection/ApplePageCorrectionEngine.swift`
  - Vision rectangle detection
  - Core Image perspective correction
  - portrait-orientation normalization
  - archive image preserved unchanged
  - conservative reading profile
  - grayscale/contrast/luminance-sharpen OCR profile
  - no automatic dewarp
  - no default hard binarization
- `scanner-parity/Tests/ImageCorrection/CorrectionCoreFixture.swift`
  - page geometry fixture
  - trapezoid perspective metric fixture
  - Otsu fixture
  - luminance fixture
  - anti-overcorrection variant-selection fixture
  - orientation fixture
- `scanner-parity/ImageCorrection/README.md`
  - profile policy, dewarp gate and Golden evaluation protocol

## Local fixture evidence

Environment:

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

Command:

```bash
swiftc \
  ImageCorrection/CorrectionCore.swift \
  ImageCorrection/ApplePageCorrectionEngine.swift \
  Tests/ImageCorrection/CorrectionCoreFixture.swift \
  -o correction-fixture
./correction-fixture
```

Observed result:

```text
CorrectionCoreFixture PASS
```

Important limitation: because Linux does not import Vision/CoreImage/CoreGraphics, the Apple adapter is conditionally excluded there. The fixture proves the platform-neutral correction core only. It is not an iOS framework compile/runtime PASS.

## Remote checkpoint read-back

After the first implementation set, compare from baseline showed the attempt branch ahead with only SCAN-002-owned files and no baseline divergence. Remote read-back of `CorrectionCore.swift` succeeded.

## Acceptance status

| Acceptance item | Status | Evidence / reason |
| --- | --- | --- |
| Detect page boundary and rectify to rectangle | PARTIAL | Apple Vision/Core Image implementation exists; iOS + Golden runtime evaluation still required |
| Auto rotation/skew correction | PARTIAL | orientation policy + geometry metrics implemented and core fixture PASS; Apple runtime evaluation pending |
| Separate reading and source-preservation outputs | PASS_IMPLEMENTED | archive is unchanged; reading and OCR images are separate profiles |
| Quantitatively compare shadow/illumination/color | PARTIAL | luminance/shadow/highlight metrics implemented; Golden measurements pending |
| Evaluate whether spread/dewarp is necessary | BLOCKED_GOLDEN | intentionally not guessed without canonical book pages |
| Evaluate `いっしょに一冊` and OSS reuse | PASS_REVIEWED | internal design reused; no third-party code adopted in this slice |
| Re-evaluate Safari original/histogram/thin-text/Otsu on same page | BLOCKED_GOLDEN | Otsu/selection guard exists, but same-page Golden comparison is unavailable; histogram/thin-text transforms not blindly promoted |

## Golden Dataset blocker

HQ startup audit found the attached candidates structurally match the migration observations but do not match the canonical SHA-256 values.

Canonical expected:

- video: `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- PDF: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`

HQ observed attached candidates:

- video: `f95fb931dd57658d139a87df8f28b2545e293728a0f7663957b4cd8d5fd7c276`
- PDF: `00f77321a221f7fb6d614a372b568c3b45292a2952bb2c113554ad2fa6d1d8c0`

HQ explicitly allows implementation/fixture and exploratory evaluation, but blocks canonical Golden PASS until either the exact canonical binaries are reattached or the current candidates are deliberately adopted and the canonical hashes are updated after confirmation.

Therefore Worker4 does **not** claim Golden PASS and does **not** claim dewarp/no-dewarp parity as verified.

## Privacy / security

This SCAN-002 implementation uses only local Apple image-processing frameworks. It adds no external AI, network upload, analytics SDK, account, secret or third-party image processor.

## Worker disposition

Recommended Queue state: `BLOCKED_HUMAN`.

Reason: all safe fixture/implementation work for this attempt has been advanced, but the remaining acceptance items require a canonical Golden Dataset decision. Requeue as a new claim epoch after the dataset mismatch is resolved, then run iOS/Golden image-level comparison before `INTEGRATION_READY`.
