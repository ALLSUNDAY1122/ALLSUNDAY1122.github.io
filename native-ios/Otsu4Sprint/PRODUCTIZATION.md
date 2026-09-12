# 危険物取扱者 乙種4類｜製品化メモ

## 採用済み仕様
- Safari価値検証版のUI・操作を製品版の基準とする。
- 問題バンク: 360問（法令144／物理・化学96／性質・消火120）。
- 無料版: 72問（法令29／物理・化学19／性質・消火24）。
- プレミアム: 全360問、全範囲の苦手・未出題、本番35問、数字・指定数量集中、詳細記録。
- 本番35問: 法令15／物理・化学10／性質・消火10、120分、終了時一括採点。3科目それぞれ60%以上を「練習上の基準到達」と表示する。
- 通常演習: 選択肢タップで即時採点、`わからない`、同画面フィードバック、3連続正解で苦手自動解除。

## コンテンツ生成・監査
1. `node tools/otsu4-build-content.mjs --check` で360問の構造監査。
2. `node tools/otsu4-build-content.mjs` で `kikenbutsu-otsu4-sprint/questions.generated.json` を生成。
3. 生成JSONをiOSターゲットのBundle Resourcesへ追加。
4. `Otsu4ContentStore` が起動時に件数・科目数・ID・選択肢・解説・出典を再検証する。

## 法令・著作権
- 公式過去問本文は製品へ転載しない。頻出論点の把握に限定し、問題文・選択肢・解説は法令・公式資料から独自に作成する。
- 問題IDは法改正後も可能な限り維持し、学習履歴・苦手履歴を引き継ぐ。
- 法令変更時は `content-sources.json` と regulation watcher の検知結果から影響問題を特定し、正答・解説を再監査して `contentVersion` を更新する。

## StoreKit 2
- 種別: Non-Consumable（買い切り）。
- Product ID: `jp.allsunday1122.otsu4.premium`。
- 価格表示: App Store Connect側の設定値を `Product.displayPrice` で表示し、アプリ内へ金額を固定値で埋め込まない。
- 権利判定の正本: `Transaction.currentEntitlements` の検証済み取引。
- `pending`、キャンセル、未検証取引では解放しない。
- 復元はユーザーが「購入を復元」を明示的に押したときのみ `AppStore.sync()` を呼ぶ。

## App Store Connectで人が行う設定
- Non-Consumable商品をProduct ID `jp.allsunday1122.otsu4.premium` で作成。
- 日本向け表示名 `乙4 プレミアム` と説明文を設定。
- 販売価格を決定。候補価格は680円相当だが、最終価格はApp Store Connect側で確定する。
- Paid Applications Agreement、税務・銀行情報など販売に必要な契約状態を確認。

## 製品化で残る作業
- Xcode/クラウドビルド用iOSプロジェクトへSwiftUI画面、学習状態、StoreKit層を統合。
- 生成済み360問JSONをBundle Resourcesへ追加。
- StoreKit Test / Sandboxで購入・保留・キャンセル・復元・返金/失効を確認。
- iPhone実機でDynamic Type、VoiceOver、Safe Area、途中復帰、オフラインを確認。
- Archive/署名/アップロード後にTestFlight内部テストを実施。
