# FP3級｜学びスプリント 申請準備

更新日：2026-11-07 JST

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

## 提出までの残作業（順序）

1. **正本AppIconを供給・確定**：9月の調査で原本不在と記録済み。新しい原本がない状態で同じ探索やAppleの加工済みBuildIconの逆利用を繰り返さない。Release用Asset Catalogへ登録し、1024px・不透明・対象Bundleを確認。
2. 問題別の内容・適用基準日の再監査。今回の利用条件確認を全件内容監査の代わりにしない。
3. この修正のネイティブSimulatorチェックと、iPhoneで学習・購入・キャンセル・pending・復元・返金の確認。
4. 公開用ページを配信し、3 URLのHTTPS/HTTP 200、アプリ内リンクを確認。
5. App Privacy、年齢区分、輸出関連、契約・税務・銀行、説明・スクリーンショット・連絡先を確認。Apple側の旧アプリ名も整理。
6. 正本から新RCを作成し、Apple処理後のビルドを実機検証。
7. 検証済みの正確なビルドと買い切り商品を同じ審査提出に含め、「審査待ち」を確認。公開時期は手動リリースを候補とし、実設定を確認する。

現在は申請可能と判定していない。AppIcon・内容監査・実機確認を通過する前に新しいRelease/TestFlightを送信しない。
