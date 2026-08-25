# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-25 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Canonical status

- Formal Golden: `PENDING_HQ_GOLDEN_EXECUTION`
- Release Gate: `NOT_STARTED`
- Workers 1-4: complete
- Queue driving: stopped
- Raw Golden: available in the current ChatGPT conversation only; raw bytes are not committed or uploaded to GitHub/Actions.

## Current integration

- Current product-code integration HEAD after Privacy hardening: `fa82253b61887e65ad0b42490e9cb6e6ae82b70f`.
- PR #4597 `scanner-parity: harden final privacy lifecycle gate on current integration` merged successfully.
- PR #4597 validated exact head: `e149282e5a7e2b6b34d95d4012930d3ca150a8dc`.
- PR #4597 exact-head `Scanner Parity Apple Validation` run `32670325018`: `completed / success`.
- PR #4597 makes `egressRisk` and `privacyRisk` non-bypassable by the generic allowlist and requires an explicit processing-workspace purge boundary instead of accepting incidental `removeItem` text as cleanup evidence.
- Superseded stale PR #4543 was closed without merge after its required delta was reapplied on the current integration base through PR #4597.
- Integration push validation run `32843550875` is a post-merge revalidation of HEAD `fa82253b...`; at the time this Evidence branch was first written it was still running and is not treated as PASS until its final conclusion is `success`.

## Prior integrated acceptance retained

The detailed pre-2026-08-25 canonical Evidence is immutable in Git history at blob:

`8b64380cdfa20129e02234adac444d2d9fac4d5b`

That evidence records successful integration of, among other gates:

- stable-frame extraction and open-book spread splitting;
- image correction;
- PageAudit;
- Japanese OCR;
- searchable PDF / TXT / Markdown / BookPackage;
- integrity verification and recovery;
- ProductFlow / AppShell / Privacy manifest;
- unsigned iPhoneOS Release build and bundle verification;
- 240-page production-runtime long-run;
- Formal Golden runner and failure recorder;
- reference alignment metrics;
- Formal machine gate;
- local visual/OCR review bundle;
- SHA-bound human review finalizer;
- SHA-bound reference-threshold calibrator.

Key integrated PRs include #4544, #4567, #4569, #4571, #4573, #4580, #4584, #4588, #4591 and #4595. None of these non-Golden or synthetic gates constitutes `FORMAL_GOLDEN_PASS`.

## Current Golden Dataset v3

The user re-supplied the bookScaner capture video and the 28-page reference PDF in the current ChatGPT conversation and explicitly confirmed that these two files are the authoritative current Golden Dataset.

Dataset version:

`golden-v3-user-confirmed-20260825`

Current raw identity:

- video SHA-256: `8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677`
- PDF SHA-256: `4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32`
- video: H.264 / 1108x512 / 288.820 s / 8661 frames / 191,911,175 bytes
- PDF: 28 pages / 1774x2429 pt / 25,751,801 bytes / no text layer
- PDF metadata Creator: `Knut Book Scanner 1.0`

The raw files are deliberately absent from GitHub and GitHub Actions. GitHub Evidence may retain only non-book-content facts such as SHA, page count, metrics, verdicts and sanitized logs.

## Golden identity history

Previous current v2 identity is retained as audit history and is not silently rewritten:

- dataset: `golden-v2-current-project-20260823`
- video SHA-256: `f95fb931dd57658d139a87df8f28b2545e293728a0f7663957b4cd8d5fd7c276`
- PDF SHA-256: `00f77321a221f7fb6d614a372b568c3b45292a2952bb2c113554ad2fa6d1d8c0`

Migration-era identity remains immutable audit history:

- video SHA-256: `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- PDF SHA-256: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`

The differences between v3, v2 and migration-era hashes are not Worker human gates. Current v3 was selected by explicit user confirmation and is HQ-owned identity versioning.

## Formal Golden execution contract

The canonical launcher remains:

`bash scanner-parity/HQGoldenRunner/run-formal-golden.sh`

The first v3 run must use:

- `--video` current raw video
- `--pdf` current raw reference PDF
- explicit `--workspace`
- `--book-id golden-v3-user-confirmed-20260825`
- `--expected-video-sha 8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677`
- `--expected-pdf-sha 4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32`
- no `--match-threshold` on the first run

The first run exists to verify current identity, run the production composition E2E, create the BookPackage/stage evidence, and capture nearest/second-best reference distances for real threshold calibration.

A pipeline failure remains `FORMAL_GOLDEN_FAIL_PIPELINE_EXECUTION` and must be root-caused by HQ before calibration. A successful thresholdless run should stop at `PENDING_REFERENCE_THRESHOLD_CALIBRATION`, not at Golden PASS.

After empirical calibration and a SHA-bound explicit threshold decision, the same v3 raw bytes must be rerun with that validated threshold. Hard machine requirements remain:

- expected video SHA match = true
- expected PDF SHA match = true
- page recall >= 99%
- unmatched output = 0
- duplicate rate <= 0.5%
- ordering accuracy = 100%
- image correction stage failure = 0
- OCR engine failure = 0
- BookPackage integrity = valid

If these pass, the state is only `PENDING_HUMAN_VISUAL_OCR_REVIEW`.

`FORMAL_GOLDEN_PASS` can be issued only by the SHA-bound finalizer after every output page receives an explicit visual-correction PASS and OCR-semantic PASS and all execution/review identity bindings match.

## Execution-host constraint discovered on 2026-08-25

The current ChatGPT sandbox containing the v3 raw files is Linux (`x86_64-unknown-linux-gnu`, Swift 6.2.1) and has no `xcrun` or `xcodebuild`.

The canonical Formal Golden package declares iOS/macOS platforms; the runner imports `PDFKit`, and the production runtime uses Apple `AVFoundation`, `CoreGraphics`, `CoreImage`, `ImageIO` and `Vision` under the production composition. Therefore the canonical real Golden run cannot be executed faithfully inside this Linux sandbox.

Moving the raw book video/PDF into GitHub Actions merely to obtain a macOS runner is prohibited by the project's copyright/privacy evidence policy. No synthetic or Linux substitute is promoted to Golden evidence.

Accordingly, the remaining execution prerequisite is a macOS 14+ environment with direct local access to the current v3 raw files and the integration source. Once that execution host is available, the first action is the thresholdless canonical command above. This is an execution-environment prerequisite, not a Worker reopening condition.

## Release Gate

`NOT_STARTED`.

Release Gate must not start until an actual `FORMAL_GOLDEN_PASS` is emitted for the current v3 identity. App Store Submit for Review, public release, contracts/tax/banking, 2FA and final iPhone human acceptance remain explicit human gates.