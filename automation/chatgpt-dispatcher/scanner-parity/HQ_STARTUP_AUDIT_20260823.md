# 書籍スキャナー同等化｜HQ Startup Audit

Timestamp: 2026-08-23 12:50 JST

## Source-of-truth read-back
- Notion `AIアプリ開発・公開フロー v2.7`: read
- Notion `申請手順`: read
- Notion `分割セッション手順 v1.1`: read
- Notion `書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本`: read
- Worker contract: read
- Shared contract: read
- Migration handoff: read
- Internal reuse assets `いっしょに一冊` / `撮る単語帳`: read
- GitHub PR #3959 / #4064: read
- `ToruTangoOcrModule.swift`: read
- `create.tsx` OCR/image-selection flow: read

## Integration / Queue
- integration branch: `scanner-parity/integration`
- queue integration_head: `99a8d30f2a09c85119869feabae9b411a3431133`
- compare `99a8d30f...` -> `scanner-parity/integration`: `identical`, ahead 0, behind 0
- integration_epoch: `1`
- queue paused: `false`
- SCAN-001: `READY`, unclaimed
- SCAN-002: `READY`, unclaimed
- SCAN-003: `READY`, unclaimed
- SCAN-004: `READY`, unclaimed
- all four task `baseline_sha` values match the current integration head

## Golden Dataset attachment verification
The expected filenames are attached, but the byte-level SHA-256 values do not match the canonical migration record.

### Video
Expected:
- filename: `RPReplay_Final1787451151.mp4`
- SHA-256: `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- migration size: `190105098` bytes

Attached candidate:
- SHA-256: `f95fb931dd57658d139a87df8f28b2545e293728a0f7663957b4cd8d5fd7c276`
- size: `191149910` bytes
- duration: `288.82 s`
- frames: `8661`
- video geometry: `1108 x 512`

The duration/frame count/geometry match the migration observation, but binary identity does not.

### PDF
Expected:
- filename: `本 2026-08-23 0842.pdf`
- SHA-256: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`
- migration size: `25751801` bytes

Attached candidate:
- SHA-256: `00f77321a221f7fb6d614a372b568c3b45292a2952bb2c113554ad2fa6d1d8c0`
- size: `25751801` bytes
- pages: `28`
- page geometry: `1774 x 2429`
- image objects: `28`
- effective OCR text layer: none

The size/page count/page geometry/image-only structure match the migration observation, but binary identity does not.

## Gate decision
- Worker Pool start: `ALLOWED`
- Fixture implementation/testing: `ALLOWED`
- Attached candidate dataset may be used for exploratory evaluation.
- Canonical Golden PASS: `BLOCKED` until the binary mismatch is resolved by either (a) reattaching the exact canonical files or (b) deliberately adopting the currently attached candidates and updating canonical hashes after confirmation.
- Do not silently overwrite canonical hashes.

## HQ ownership
HQ owns `shared-contract`, `app-shell`, `integration`, Parity aggregation, Privacy Gate, Release Gate, and finalization. Workers may not mark `MERGED` / `VERIFIED` or redefine the shared contract.
