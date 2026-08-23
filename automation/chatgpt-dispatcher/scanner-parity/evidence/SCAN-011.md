# SCAN-011 Evidence｜Privacy Static Audit

更新: 2026-08-23 16:31 JST
Worker: worker2
Claim epoch: 1
Attempt branch: `task/SCAN-011/attempt-1`
Baseline: `45e420e9befb52ccb1b26837f3c7fd41078701c3`
Attempt head: `9d6ddbcc0b89ea7b0447b807ad679b7358dbf2a9`
Golden: `NOT_APPLICABLE_WORKER`
Privacy release decision: `HQ_RELEASE_GATE_REQUIRED`

## 結果

非Golden acceptanceは完了。`INTEGRATION_READY` 推奨。

現行integrationの書籍データ処理上、直接のnetwork / analytics SDK / external AI送信経路は、確認したproduction-sensitive pathでは観測されなかった。ただし静的token監査だけで間接通信・動的ロード・OS管理通信まで不存在証明はできないため、最終Privacy PASS/FAILはHQ Release Gateに残す。

## 実装

- `scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift`
  - network API (`URLSession`, `URLRequest`, `NWConnection`, WebSocket等)
  - network CLI (`curl`, `wget`, API endpoint marker)
  - analytics SDK (`FirebaseAnalytics`, Mixpanel, Amplitude, Sentry, PostHog等)
  - external AI (`api.openai.com`, Anthropic, Gemini, Replicate等)
  - local CLI (`Process`, tesseract, ocrmypdf, python3, ffmpeg, xcrun等)
  - Apple local framework (Vision/VisionKit/PDFKit/CoreGraphics/CoreImage/AVFoundation/ImageIO等)
  - remote package dependency
  をカテゴリ別に静的列挙する。
- `egressRisk` ルールはallowlistで解除不能。allowlistは既知ローカルCLI等のreview/infoノイズだけを抑制できる。
- production判定から `/Tests/` を除外し、denylist fixture自体の誤検知を防止。
- `.sh` もscan対象にし、将来shell経由で追加される `curl` / `wget` を検出可能にした。
- `run-current-audit.sh` はproduction treeをscanし、egressRisk検出時にnon-zero終了する。

## Fixture

`PrivacyStaticAuditorTests.swift` に12ケースを保存:

1. URLSession => egress risk
2. OpenAI endpoint => external-AI egress risk
3. analytics SDK => egress risk
4. Apple Vision => local/info
5. Tesseract Process => local CLI/review, not egress
6. Process内curl => egress risk
7. custom denylist => future SDK検出
8. allowlist => approved local CLI reviewのみ抑制可能
9. allowlistでURLSession egress ruleは解除不能
10. Tests pathはproduction scanから除外
11. remote package => review, not data egress by itself
12. 最終判定は常にHQ gate required

初期10ケースはSwift compile/runで `RESULT passed=10 failed=0` を確認。allowlist hardening後の追加2条件はSwiftで独立compile/runし `PASS non-bypassable-egress` / `PASS local-allowlist` を確認。repositoryには12ケースを一括再実行する `run-fixtures.sh` を保存済み。

## 現行integrationのデータフロー観測

### FrameExtraction
`AVFoundationStableFrameExtractor.swift`
- AVFoundation/CoreVideo/ImageIO
- local video URLを読み、local candidate image / manifestへ出力
- direct network transport未観測

### ImageCorrection
`ApplePageCorrectionEngine.swift`
- CoreImage/Vision/CoreGraphics
- local image correction
- direct network transport未観測

### PageAudit
`VisionPageAuditRecognizer.swift`
- Vision/ImageIO
- `VNRecognizeTextRequest` + local image URL
- direct network transport未観測

### OCRExport
`AppleVisionBookOCR.swift`
- Vision/ImageIO
- `VNRecognizeTextRequest` + local image URL
- external AI/APIなし

`TesseractComparison.swift`
- Foundation `Process`
- executable `/usr/bin/tesseract`
- stdout/stderr pipeのみ
- local CLI comparisonとして分類。network transportではない

`BookPackageWriter.swift`
- FileManager/Data local write
- pages/text/manifest/PDFをlocal destinationへ生成

`SearchablePDFWriter.swift`
- UIKit/CoreText local searchable-PDF生成

`OCRExport/Package.swift`
- external package dependencyなし

## Scope監査

baselineとのremote compareで変更は以下のみ:

- `scanner-parity/PrivacyAudit/PrivacyStaticAuditor.swift`
- `scanner-parity/PrivacyAudit/README.md`
- `scanner-parity/Tests/PrivacyAudit/PrivacyStaticAuditorTests.swift`
- `scanner-parity/Tests/PrivacyAudit/run-fixtures.sh`
- `scanner-parity/Tests/PrivacyAudit/run-current-audit.sh`

SCAN-011 write_scope外の変更なし。

## Acceptance対応

1. network/analytics/外部AI依存の静的列挙: 実装済み。
2. 書籍画像/OCR本文の端末外経路: current sensitive pathsではdirect egress未観測。静的監査の限界を明記。
3. Apple framework / local CLIの区別: Vision等=local info、Tesseract Process=local CLI reviewとして分離。
4. denylist/allowlist fixture: 実装済み。egress ruleはallowlistで無効化不能。
5. 最終Privacy PASS: Workerでは付与せずHQ Release Gate所有を維持。

## 残余リスク / HQ Gate

- 静的token scannerはreflection/dynamic loading/難読化/間接依存を完全には証明できない。
- Apple標準frameworkの内部OS通信有無と、アプリが書籍本文を明示送信することは区別する。
- HQ Release Gateでは、必要に応じ dependency graph / entitlements / network capture / App Privacy申告整合を追加確認する。
- 将来外部AI/analytics/network SDKを追加した場合、明示同意・保持/ログ監査・Privacy申告整合を別Gate化する。
