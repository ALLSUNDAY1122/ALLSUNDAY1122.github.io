# FP3級｜学びスプリント 申請準備

更新日：2026-11-08 JST

## 正本

- ソース：`fp3-manabi-sprint/`。SwiftUI + WKWebView + StoreKit 2買い切り。
- Bundle ID：`com.allsunday1122.fp3kakomoncoach`
- ASC App ID：`6796733578`
- Product ID：`com.allsunday1122.fp3kakomoncoach.premium.lifetime`
- 旧 `fp3-kakomon-coach/ios-app` の月額200円＋買い切り980円構成は現行正本へ持ち込まない。

## Appleの最新確認

2026-11-07 17:33 JSTに読み取り専用で確認。証拠は `audits/apple-release-state-20261107.json`。

- アプリ名はApple側ではまだ「FP3級 過去問コーチ」。現行ブランドへの統一は未実施。
- iOS版1.0：`PREPARE_FOR_SUBMISSION`。
- 買い切り商品：`READY_TO_SUBMIT`。
- 日本語の商品名・説明、価格スケジュール、日本の配信地域、審査用画像が存在。
- 配信地域は全ページ取得し `JPN` のみと確認。
- EAS CLIのApple readbackで既存ビルド7・9は処理済みだがTestFlight期限切れと確認。
- 契約・税務・銀行、App PrivacyのUI最終状態は今回未確認。

## 今回の修正

- 回答直後に再起動しても、採点済み状態を復元し、同じ回答を二重集計しない。
- 苦手登録・3連続正解の集計を途中復帰で維持する。
- 解説に原典の公表年月・問題番号・リンク・加工表示・基準日を表示。
- 設定にPremium入口・購入復元・サポート等への導線を追加。
- 購入／復元の多重開始を防ぎ、キャンセル後に購入ボタンが永久に無効にならないよう修正。
- `privacy.html` / `terms.html` / `support.html` を作成。PR段階のため公開URLのHTTP確認は未完了。
- Apple読み取りスクリプトの件数上限・v2 localizationパスを修正し、実APIで成功確認。

## 今回の検証結果

- セッション回帰6件、API/FP2構造検査回帰11件がPASS。GitHubの資格情報を使用しない回帰CIも成功。
- [iPhone Simulatorの実走](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42356365949)が成功。iPhone 17 Proで購入画面・価格表示・復元ボタンを確認し、PNGを取得・目視確認済み。
- Simulatorの価格は同梱 `Review.storekit` のテスト価格。実App Storeの価格確認や実機での購入・返金検証を代替しない。
- 詳細は `audits/VALIDATION_20261107.md`。

## 2026-11-08 AppIcon正本照合・XcodeGen / Simulator確認

- 正本: 2026-11-08にユーザーが添付した再構成PNGのみ（旧PC icon.png・ASC BuildIconは不採用）。原本1024×1024、RGB、アルファなしを実測。正本SHA-256 `095f23a9829f0e1e8316e92160da2af8cec0c24c4ae53cb7582ccbb9b88ef51f`。
- GitHub登録: `f0780e29b1082491096553d6e5abc7c5938bde32`、`ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`、753675 bytes。GitHubのGit Blob SHA-1 `73687ddaba202b092ad6a0664635a9db8fc3478b` と添付正本から同仕様で独立算出したSHA-1が完全一致し、同一バイト列と判断。正本のSHA-256も独立算出済み。
- `Contents.json` に universal / ios / 1024x1024 / AppIcon-1024.png を設定済み。`project.yml` は `Assets.xcassets` をsourcesへ追加し `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` を指定済み。対象Bundleは `com.allsunday1122.fp3kakomoncoach`。
- GitHub Actions [run 42477640577](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42477640577)、コミット `c50e1a4cfc93a792be4bd147b16792bad1a8b2a3`: `regression` success、`fp3-release-icon-simulator` success。macOSで正本SHA-256・PNG RGB 1024・透明チャンクなし・CatalogとXcodeGen設定を検証後、XcodeGen導入、`prepare-ios.sh`、`xcodegen generate`、署名なしiOS Simulator `xcodebuild ... build` の全工程が成功。
- `fp3-preflight.yml` という別ワークフロー自体の新規実行は未確認（本ジョブでAppIcon検証とネイティブSimulatorのビルド工程を実行）。App Store向け署名アーカイブ、TestFlight配信、実機購入、App Reviewは行っていない。
- 初回CIでPNGシグネチャ比較コードにエスケープのバグがあり `42477554891` / `42477577188` の新ジョブが失敗。検証コードを `c50e1a4` で修正後、run 42477640577 がsuccess。画像本体の不一致ではない。

AppIcon供給・内容同一性・Simulatorビルドのゲートは解消。ただし180問内容再監査、iPhone実機StoreKit、公開URLおよびASC提出項目最終確認は継続。Release/TestFlightと本番審査提出の停止条件は維持する。

## 提出までの残作業（順序）

1. **正本AppIconの組込確認は完了**：2026-11-08正本SHA-256一致、Asset Catalog、XcodeGen、SimulatorビルドをGitHub ActionsでPASS。実機ホーム画面での見え方は別途最終確認。
2. 問題別の内容・適用基準日の再監査。今回の利用条件確認を全件内容監査の代わりにしない。
3. この修正のネイティブSimulatorチェックと、iPhoneで学習・購入・キャンセル・pending・復元・返金の確認。
4. 公開用ページを配信し、3 URLのHTTPS/HTTP 200、アプリ内リンクを確認。
5. App Privacy、年齢区分、輸出関連、契約・税務・銀行、説明・スクリーンショット・連絡先を確認。Apple側の旧アプリ名も整理。
6. 正本から新RCを作成し、Apple処理後のビルドを実機検証。
7. 検証済みの正確なビルドと買い切り商品を同じ審査提出に含め、「審査待ち」を確認。公開時期は手動リリースを候補とし、実設定を確認する。

現在は申請可能と判定していない。AppIconは解決済みだが、内容再監査・実機確認等を通過する前に新しいRelease/TestFlightを送信しない。
