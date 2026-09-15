# 司法試験予備試験・短答式｜App Storeメタデータ案

更新: 2026-08-14
状態: DRAFT / 正式3回分Release・App Store Connect実登録完了前は提出しない

## v2.4で確定した識別子・課金

- Bundle ID: `jp.allsunday1122.yobishikentantou`
- 課金方式: 自動更新サブスクリプション（月額）
- 日本向け基準価格: 月額200円（App Store Connect設定値。アプリ内へ固定文字列として埋め込まない）
- planned IAP Product ID: `jp.allsunday1122.yobishikentantou.monthly`
- runtime IAP設定: App Store Connectへ同一Product IDを実登録し、取得確認するまでは未設定のままfail-closed
- アプリ内価格表示: StoreKit `Product.displayPrice` のみ

## 固定可能な原稿

- App名案: `予備試験 短答｜学びスプリント`
- サブタイトル案: `8問で回す予備試験の短答対策`
- プライマリカテゴリ案: `教育`
- サポートURL: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/support/`
- プライバシーポリシーURL: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/privacy/`
- ログイン: 不要
- 広告: なし
- 分析SDK: なし
- 学習データ: 端末内保存＋利用者操作のJSON入出力
- 無料範囲: 最初の1スプリント最大8問。サブスクリプションの無料トライアルとは表現しない。

## 説明文案

「司法試験予備試験・短答式｜学びスプリント」は、長時間の問題演習ではなく、短い反復を積み重ねるための学習アプリです。

今日のスプリントは標準8問。通勤・休憩などの短い時間でも、少しずつ法律科目の知識を確認できます。最初の1スプリントは最大8問まで無料で利用できます。

主な機能：
- 標準8問の短時間スプリント
- 憲法・行政法・民法・商法・民事訴訟法・刑法・刑事訴訟法・一般教養の分野別演習
- 独自模擬試験（正式教材監査を通過した問題のみ）
- 間違えた問題の苦手復習
- 3回連続正解で苦手を解除
- 「わからない」問題の記録
- 途中再開
- 正答率・分野別記録・5週間ヒートマップ
- 試験日までの残日数と必要学習ペース
- JSONによる学習データの書き出し／読み込み
- オフライン学習

分野別演習、模試、苦手復習などのプレミアム機能は、自動更新サブスクリプションで解放します。購入画面にはApp Storeから取得したローカライズ済み価格を表示します。

法律科目は問題単位で法令基準日と一次根拠を管理します。正式教材へ入れる問題は、正答、根拠、法令基準、重複・高類似、利用条件を監査してから収録します。

本アプリは法務省その他の公的機関の公式アプリではありません。

## キーワード案

`司法試験,予備試験,短答,法律,憲法,民法,刑法,行政法,会社法,民事訴訟法,刑事訴訟法`

## Promotional Text案

1日8問から。苦手を見つけ、3回連続正解でつぶす短答学習。

## What's New 1.0.0案

初回リリース。
- 8問スプリント
- 分野別演習・模試・苦手復習
- 学習記録・途中再開・JSONバックアップ
- オフライン学習

※正式リリース時に実装済み機能だけへ再照合する。

## App Privacy案

実装正本 `ios/PrivacyInfo.xcprivacy` と公開Privacy Policyに基づく。
- 開発者によるデータ収集: なし
- Tracking: なし
- 第三者広告: なし
- Analytics SDK: なし
- UserDefaults: 端末内の設定・学習状態保存のため利用。Privacy Manifest理由 `CA92.1`
- StoreKit 2: Apple経由の購入・復元・購入資格確認

App Store Connectの質問文が変更された場合は、申請時の現行質問に対して実装から回答を再生成する。

## 未確定・推測禁止

- App Store Connect Apple ID: 実発行値待ち
- SKU: App Store Connect作成時に正本化
- IAP Product ID: planned値は `jp.allsunday1122.yobishikentantou.monthly`。App Store Connect実登録一致確認までruntime未設定
- サブスクリプショングループ: App Store Connect作成時に実値を記録
- App Store Connectの年齢レーティング最終回答: 現行質問票で再確認
- Copyright表示の最終名義: 要確認
- スクリーンショット: 正式教材Release後の実機相当画面から作成

## 禁止

- 正式問題数が未確定なのに「3年分○問収録」と記載しない。
- 法務省公式・公認・監修と誤認させる表現を使わない。
- アプリ内へ価格文字列を固定しない。
- CBT体験版の画面・画像・収録コンテンツをApp Store素材へ転用しない。
