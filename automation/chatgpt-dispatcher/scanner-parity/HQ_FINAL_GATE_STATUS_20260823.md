# 書籍スキャナー同等化｜HQ Final Integration / Golden Gate Status

Updated: 2026-08-23 17:59 JST

## Final integration
- Final HQ PR: #4532 `scanner-parity: HQ final cross-lane integration`
- PR head at validation: `7bb79cf68fa66ddd339155606e3137a4b54192b7`
- Merged into `scanner-parity/integration`
- Merge commit / current integration HEAD: `846bef866502bbb4065381c6845d2aacf28590d6`
- `compare(846bef..., scanner-parity/integration)` = identical / ahead 0 / behind 0

## Final Apple / source / privacy validation
GitHub Actions run: `32629630372` (`Scanner Parity Apple Validation`, run #36)
Job: `97170284932` (`apple-sdk-compile`)
Conclusion: PASS

Validated on macOS runner / Xcode 26.6 / iPhoneOS SDK 26.5 / target arm64-apple-ios17.0:
- legacy Apple adapter harness contract: PASS
- FrameExtraction iPhoneOS compile: PASS
- ImageCorrection iPhoneOS compile: PASS
- PageAudit iPhoneOS compile: PASS
- cross-module Apple contract probe: PASS
- final source contract: 20 passed / 0 failed
- privacy/security gate fixtures: PASS
- privacy static audit: `egress_risk_findings=0`; final release Privacy decision remains HQ-owned
- SwiftPM manifest resolution: root, ReviewCore, Recovery, ProductFlow, AppShell all PASS
- ScannerRuntime iPhoneOS module compile: PASS
- ReviewCore iPhoneOS module compile: PASS
- Recovery iPhoneOS module compile: PASS
- ProductFlow iPhoneOS module compile: PASS
- AppShell iPhoneOS module compile: PASS
- final marker: `PRODUCT_APPLE_SDK_COMPILE_PASS`

A first full-product run correctly exposed a real SwiftUI `App.init()` conformance failure. HQ fixed the explicit no-argument App initializer and removed an invalid `Sendable` declaration that stored `FileManager`; the final run above is the post-fix PASS.

## Golden Dataset identity resolution
Legacy migration identity is preserved and is NOT overwritten:
- video legacy expected SHA-256: `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- PDF legacy expected SHA-256: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`

Current project attachments observed by HQ:
- `RPReplay_Final1787451151.mp4`
  - SHA-256: `f95fb931dd57658d139a87df8f28b2545e293728a0f7663957b4cd8d5fd7c276`
  - bytes: `191149910`
  - H.264, 1108x512, 8661 frames, 288.820 s, ~29.99 fps
- `本 2026-08-23 0842.pdf`
  - SHA-256: `00f77321a221f7fb6d614a372b568c3b45292a2952bb2c113554ad2fa6d1d8c0`
  - bytes: `25751801`
  - 28 pages, 1774x2429 pt each, PDF 1.3, not encrypted, no extractable text layer
  - rendered-thumbnail combined SHA-256: `36130d7eccb2c9cd6d0d919c70090b9c3361eb69bcf7d62493ae4cf163180bc9`

### HQ decision
The byte-level SHA mismatch is resolved by VERSIONING, not by silently replacing the legacy identity.

- `golden-v1-legacy-migration`: historical expected hashes retained above.
- `golden-v2-current-project-20260823`: the currently attached video/PDF pair with the observed hashes above is the active dataset for the next same-Golden execution.
- This decision does not claim that v1 and v2 are byte-identical.
- The structural fingerprints match the migration description closely (same filenames, video geometry/frame count/duration class, PDF exact byte size/page count/page geometry/no-text-layer profile), which is sufficient to register the current user-provided pair as a new explicit Golden version while preserving provenance.
- Raw Golden files remain outside GitHub; only hashes/metadata/evidence are stored here.

## Current Gate state
- final cross-lane integration: PASS / MERGED
- Apple full-product compile: PASS
- source contract: PASS
- privacy/security technical regression: PASS, final Release Privacy gate still later
- Golden dataset identity: `RESOLVED_VERSIONED_CURRENT_ATTACHMENTS`
- formal same-Golden end-to-end parity measurement: `PENDING_HQ_GOLDEN_EXECUTION`

Formal Golden PASS/FAIL must still be based on the integrated production pipeline processing `golden-v2-current-project-20260823` end-to-end and producing the defined page recall / transition / duplicate / ordering / correction / OCR / searchable-PDF / BookPackage metrics. Byte identity resolution alone is not Golden PASS.
