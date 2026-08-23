# 書籍スキャナー同等化｜次期HQセッション引き継ぎ

時点: 2026-08-23 19:55 JST

## 最重要運用
- 会話履歴を正本にしない。開始時に必ず Notion / GitHub / integration HEAD / Evidence を fresh read する。
- Worker 1〜4 のAutonomous LanesとHQ最終統合は完了済み。今後はWorkerを再起動せず、HQが Golden Gate → 実機/TestFlight → Release Gate を担当する。
- PoC成功、compile成功、OCR単体成功、PDF生成成功だけで完成判定しない。

## 正本
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Integration branch: `scanner-parity/integration`
- Dispatcher branch: `automation/scanner-parity-dispatcher`
- Notion: `書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本`
- Notion page id: `3c509c10-697d-8139-867e-c3f7605665ed`
- Shared contract: `scanner-parity/SHARED_CONTRACT.md`

## 最新統合状態
- PR #4532 `scanner-parity: HQ final cross-lane integration` は統合済み。
- PR #4535 `scanner-parity: add real iOS application target` は統合済み。
- 最新 integration HEAD: `a306302e8cc95b6eb54af3c6db60cac083e772b2`
- merge後 compare: integration は HEAD と identical（ahead 0 / behind 0）。

## iOS Application target
- `scanner-parity/iOSApp/project.yml`
- XcodeGenによる実Application target `ScannerParity`
- iOS 17 / iPhone-only / SwiftUI
- AppShell → ProductFlow → ScannerRuntime / ReviewCore / Recovery を実接続済み。
- Production Bundle ID / Version / Build番号は推測せず未確定のまま。`SCANNER_PARITY_BUNDLE_ID` / `SCANNER_PARITY_MARKETING_VERSION` / `SCANNER_PARITY_BUILD_NUMBER` の実値は申請preflightでApple正本から確定する。
- CIでは非リリース検証値だけを使用する。

## Apple CI 最終PASS
- Workflow: `Scanner Parity Apple Validation`
- 最終head: `8e3721beb9e0b11bc026b01ecbe3ea743d1fe04f`
- Run id: `32634402276`
- Run number: `62`
- Conclusion: SUCCESS
- PASS内容:
  - Apple adapters iPhoneOS compile
  - final source contract 20/20
  - Privacy/Security gates
  - SwiftPM dependency resolution
  - ScannerRuntime / ReviewCore / Recovery / ProductFlow / AppShell iPhoneOS compile
  - XcodeGen project generation
  - unsigned Release build for generic iPhoneOS
  - actual `ScannerParity.app` bundle / executable / Info.plist / PrivacyInfo.xcprivacy verification

## CIで発見し修正済みの重要点
- SwiftPMが複数の `PrivacyInfo.xcprivacy` をScannerRuntime resourceとして拾う問題を除外設定で解消。
- AppShellのlocal package product参照を明示し、ScannerRuntime / Recovery / ReviewCore のpackage product resolutionを修正。
- 実`.app` bundleが生成されるまでmergeしないGateを導入済み。

## Evidence
- `automation/chatgpt-dispatcher/scanner-parity/evidence/HQ-IOS-APP-TARGET-20260823.md`
- ここにiOS Application target・Apple CI PASS・Golden Gate readinessを記録済み。

## 現在の唯一の主要未完了: HQ_GOLDEN_GATE
正式な実書籍同一入力E2E測定はまだ未完了。
必要なユーザー提供原本:
- `RPReplay_Final1787451151.mp4`
- `本 2026-08-23 0842.pdf`

前セッションでは current-conversation uploads / File Library を再検索したが、正本binaryを取得できなかった。無関係ファイルを代用してはいけない。
次期セッションでユーザーが再添付したら、最初に実ファイルのSHA-256・サイズ・動画メタデータ・PDFページ数をread-backし、Golden identityを確定してから測定する。旧migration SHAと一致しない場合も黙って上書きせず、versioned Goldenとして履歴を残す。

参考として以前の実添付候補で確認された構造:
- 動画: 1108x512 / 30fps / 約288.820秒 / 8661 frames / 約191MB
- PDF: 28ページ / 約1774x2429 / OCR layerほぼ無し
ただし、次期セッションでは再添付実体を正とし、上記を正本値として決め打ちしない。

## Golden Gateで必ず測る項目
- ページ再現率 >= 99%
- ページ送り途中の採用 = 0
- 重複率 <= 0.5%
- ページ順序 = 100%目標
- 抜け / 逆転 / 重複検出と修復
- 台形 / 傾き / crop / 色 / 影 / 必要時dewarp
- 日本語横書き / 縦書き / mixed OCR品質
- searchable PDF text layer
- `pages/*.jpg`, `text/*.txt`, `book_searchable.pdf`, `book.md`, `book.txt`, `manifest.json` のBookPackage完全性
- AI投入用lineage / source_time_ms / page boundary順序
- review_required / fail-closeが正しく残ること

## Golden Gate後
GoldenがPASSしたら次に:
1. 実iPhone/TestFlight受入準備
2. Apple実発行 Bundle ID / App ID / Version / Build番号のcanonical化
3. Support URL / Privacy Policy / App Privacy / Age Rating / export compliance / Review Detail / screenshots監査
4. signed build / Internal TestFlight
5. 実iPhone最終受入
6. Release Gate

`Submit for Review`、公開、2FA、契約・税務・銀行、実機最終承認はhuman-only Gateのまま。

## 次期HQの開始アクション
1. Notion page `3c509c10-697d-8139-867e-c3f7605665ed` をfresh fetch。
2. GitHub `scanner-parity/integration` HEADをfresh fetch/compareし、上記HEADから変更がないか確認。
3. Evidence `HQ-IOS-APP-TARGET-20260823.md` を読む。
4. Golden 2ファイルが添付されていれば即座にidentity確定→same-input E2E測定へ進む。添付されていなければ、その2ファイルの再添付だけをユーザーへ依頼する。
5. Golden PASSまでは「完成」と判定しない。
