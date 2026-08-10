# 情報処理安全確保支援士｜学びスプリント RELEASE STATUS

更新基準日: 2026-08-10

## 現在地

- 開発連番: #8
- 段階: 公開準備 / ChatGPT担当完了 / 次担当AI・Apple入力待ち
- Safari初期試作品: iPhone実機 HUMAN PASS
- Safari製品候補版: iPhone実機 HUMAN PASS
- GitHub Pages: `https://allsunday1122.github.io/sc-manabi-sprint/full/`
- iOS方式: Capacitor 8.4.2 / app内Web資産同梱 / iPhone-only
- Bundle ID暫定: `jp.allsunday1122.scmanabisprint`
- Version: `1.0.0`
- Build: ローカル/GitHub preflightは1、Codemagic signed buildは `CM_BUILD_NUMBER` を使用

## 問題バンク

- IPA公開済み過去問: 75問（3回×25問）
- シラバス・一次資料準拠の独自問題: 250問
- 合計: 325問
- 模試: 各試験回を前半13問 / 後半12問へ分割
- 2026年度以降の非公開本試験問題は、受験者記憶・SNS・漏洩情報から復元しない
- 問題、正答、解説、根拠、試験構成を変更した場合は問題生成・監査ループPASSを失効させ再監査する

## 品質状態

- 問題生成・監査: PASS
- 正答・一次根拠監査: PASS
- 著作権・IPA利用条件監査: PASS
- 制度監査: PASS
- UI品質: HUMAN PASS後の修正を反映済み
- iOS unsigned Simulator build: PASS
- iOS unsigned physical-device Release build: PASS
- IAP追加後のmacOS CI: PASS
- build-number対応変更後の実装検証: **PASS**
- 最新確認済みGitHub Actions run: `31375145017` / success
- 最新検証source: `9b1bf60f2ad19ef9603f8d86753fc36dc64eebc0`

## 収益方式

ユーザー承認済み: **B = 無料 + 一部機能を有料化**

### 無料
- IPA公開過去問75問
- 4 / 8 / 16問スプリント（75問から出題）
- 公開過去問3回の模試
- 公開過去問の苦手復習
- 基本記録、試験日、文字サイズ、JSON入出力

### プレミアム
- Non-Consumable（買い切り）
- Product ID: `jp.allsunday1122.scmanabisprint.premium`
- 独自250問を追加して全325問
- 全325問スプリント
- 全325問の苦手復習
- 分野別集中演習
- 購入復元を常設
- 価格はStoreKitから取得し、アプリコードへ固定しない
- **販売価格は未最終承認。600円は提案値であり確定値ではない。**

## App Store申請資産

作成済み:
- App Store日本語メタデータ案
- App Review Notes
- Privacy Policy公開ページ
- Support公開ページ
- PrivacyInfo.xcprivacy
- 学習データ初期化
- ITSAppUsesNonExemptEncryption = NO 設定
- IAP仕様書 / 購入・復元実装
- 申請前リリース監査記録
- `CODEX_HANDOFF.md`（Codex / Claude共用の本実装引継ぎ）
- `app-store/codemagic-sc-workflow.yaml`（root Codemagic定義へ統合する署名ビルド準備）

AppIcon正本:
- Google Drive: `08_情報処理安全確保支援士試験.png`
- Drive file ID: `1HuyIsiuQFmCbW266NbZIz5YM7tC08fON`
- 1024×1024 / RGB
- SHA-256: `6bf2945788da0be45b9e448ea79d5c40ac197e97d6bed387d4215c50d486bb3d`
- 申請時は別デザインを生成せず、この個別PNGを使用する

## 人間入力が必要な未完了事項

1. 次担当AI（Codex / Claude）の選択
2. 正本AppIconをiOS資産へ取り込む（次担当AIがDrive正本を使用）
3. SC用Codemagic workflowをroot `codemagic.yaml`へ統合
4. Bundle ID最終承認
5. App Store Connect Appレコード作成
6. Paid Apps Agreement、税務・銀行等のApple契約状態確認
7. Non-Consumable IAP作成
8. プレミアム販売価格最終承認
9. Apple Developer Team / 証明書 / provisioning / 2FA
10. signed IPA → TestFlight
11. Sandboxで購入・キャンセル・復元・購入済みオフライン再起動を実機確認
12. TestFlight実機確認
13. TestFlight実画面からApp Storeスクリーンショット取得
14. Age Rating / Content Rights / App Privacy最終入力
15. App Store提出の最終承認

## 再発火原則

コード、UI、問題、制度、著作権、課金、Privacy、外部通信、保存方式のいずれかを変更した場合、その変更に影響する既存PASSを失効させ、該当品質ループをPASSまで再実行する。
