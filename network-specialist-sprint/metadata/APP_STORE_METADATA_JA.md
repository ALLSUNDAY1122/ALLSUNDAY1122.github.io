# App Store Metadata｜ネットワークスペシャリスト｜学びスプリント

- App Store表示名候補：ネットワークスペシャリスト｜学びスプリント
- サブタイトル候補：科目A-2を8問ずつ反復
- カテゴリ：教育
- 年齢：4+（App Store Connectで実装内容と再照合する）
- 本体価格：無料想定
- IAP：StoreKit 2・非消耗型買い切り機構を実装済み。ただし #7 Product ID は正本未記載のため、Product ID確定・App Store Connect商品設定・課金監査PASSまでRelease blocker。
- IAP価格表示：固定価格を書かず、App Storeの商品情報 `Product.displayPrice` をアプリ内表示に使用する。
- サポートURL：https://allsunday1122.github.io/network-specialist-sprint/support.html
- プライバシーURL：https://allsunday1122.github.io/network-specialist-sprint/privacy.html

## 説明文
ネットワークスペシャリスト試験の科目A-2（旧午前II）を、短い学習単位で反復する試験対策アプリです。

通常学習では、直近3回分の出題を監査し、同一・実質同一の再出題を重複問題として水増しせず、ユニーク問題として整理しています。模擬試験では2025年度・2024年度・2023年度の各25問の出題枠を試験回単位で学習できます。

主な機能：
- 4／8／16問の短時間スプリント
- 2025・2024・2023年度の25問演習
- 誤答・「わからない」の苦手自動記録
- 3連続正解で苦手解除
- 分野別記録、5週間ヒートマップ
- 試験日カウントダウン
- JSONバックアップ／復元
- オフライン学習

本アプリは独立した学習アプリであり、独立行政法人情報処理推進機構（IPA）の公式アプリではありません。IPA公開問題を基に改変した問題は、アプリ内で出典情報を確認できます。

※プレミアム機能の公開内容は、正本Product IDとApp Store Connect商品設定が確定した後に、実装と一致する文言を追記する。未確定の価格・解放範囲は申請原稿へ記載しない。

## キーワード候補
ネットワークスペシャリスト,NW,情報処理技術者,IPA,午前II,科目A-2,過去問,資格,試験,学習

## Reviewメモ
- サインイン不要。
- アカウント登録なし。
- 広告・解析なし。
- 学習データは端末内保存。
- StoreKit 2の非消耗型IAPを使用する構成。購入権利は検証済み `Transaction.currentEntitlements` を基準にし、未検証・pending・cancel・revocationでは解放しない。
- 「購入を復元」はユーザー操作時のみ `AppStore.sync()` を実行する。
- 初回起動後、ホームの「今日のスプリント」から1タップで学習開始可能。
- TestFlightはInternal Testing only。本審査への自動提出は禁止。
