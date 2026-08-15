# Codex引き継ぎ｜開発連番#12 不動産鑑定士試験・短答式｜学びスプリント

更新日: 2026-08-15

## 役割
このブランチの開発を継続する。ユーザー確認が本当に必要な工程まで自律的に進め、既完了工程のやり直し、単なる「次」待ち、同じ失敗操作の反復は禁止する。

作業前にGitHub最新HEAD、PR #4138、Notion正本を再取得し、この文書より新しい実状態があれば実状態を優先する。

## GitHub
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Branch: `feat/kanteishi-shortanswer-sprint-12`
- Draft PR: `#4138`
- App root: `kanteishi-shortanswer-sprint/`
- iOS root: `kanteishi-shortanswer-sprint/ios/`
- XcodeGen: `kanteishi-shortanswer-sprint/ios/project.yml`
- root Codemagic: `/codemagic.yaml`
- Codemagic workflow key: `kanteishi-shortanswer-ios`

## Notion正本
- アプリ台帳: `3b609c10-697d-813f-8d55-fa0735c1e502`
- 対象アプリ識別情報: `3b709c10-697d-8138-a352-c422d4dd5c47`
- 申請手順: `3b009c10-697d-81eb-a325-f86d8af55481`
- 標準手順: 現行最上位版を再取得して適用

## 完成状態
- 国土交通省公表の令和8・7・6年短答式をcanonical化済み
- 3年度×80問=240問、行政法規120/鑑定理論120、全問5択
- ID重複0、人工水増し0、第三者権利要確認0
- SwiftUI native / iPhone専用 / iOS 17+ / portrait
- 今日の4/8/16問、年度別80問、年度×科目40問、苦手/わからない、3連続正解解除、中断復帰、履歴、5週ヒートマップ、JSONバックアップ、オフライン学習を実装済み
- 無料24問 / プレミアム240問
- StoreKit 2 自動更新サブスクリプション、購入復元、verified + Product ID一致 + 未取消のみ権利付与
- AppIcon正本を実バイナリ統合済み。SHA-256: `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- Kanteishi Short Answer / Official 240 / AppIcon Contract は直近監査PASS

## Apple識別情報
確定:
- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- App Store Connect Apple ID: `6801787074`
- SKU: `kanteishi-shortanswer-sprint-ios`
- Codemagic profile: `kanteishishortanswer_appstore`

App Store Connect Appレコードは2026-08-15に作成済み。Apple IDは画面実値から取得しNotion正本へ記録済み。

## 課金
- 方式: 自動更新サブスクリプション（月額）
- 日本向け基準価格: 200円
- 初回無料期間: なし
- 価格表示: StoreKit `Product.displayPrice`
- planned Product ID: `jp.allsunday1122.kanteishishortanswer.monthly200`
- actual Product ID: App Store Connect実登録値のみを正本化する

重要: actual Product IDを登録確認するまでrelease buildへ有効化しない。

## Codemagic
root `codemagic.yaml` に `kanteishi-shortanswer-ios` workflow追加済み。
- distribution_type: app_store
- bundle_identifier: `jp.allsunday1122.kanteishishortanswer`
- `PREMIUM_PRODUCT_ID` 未設定ならrelease buildを明示FAIL
- Internal TestFlight only
- `submit_to_testflight: true`
- `submit_to_app_store: false`

## 現在の実ゲート
**SUBSCRIPTION REGISTRATION HUMAN GATE**

Apple Appレコード作成と数値Apple ID取得は完了した。

次の人間操作:
1. App Store Connectで当該Appを開く
2. 収益化 / Monetization → サブスクリプション / Subscriptions
3. 最初のサブスクリプショングループを1つ作成
4. 月額自動更新サブスクを作成
5. Product IDは `jp.allsunday1122.kanteishishortanswer.monthly200`
6. Durationは1 Month
7. 日本向け基準価格を200円に設定
8. 無料トライアルは設定しない
9. actual Product IDが画面上で確認できたら正本化

actual Product ID登録後は確認質問を増やさず、Notion/GitHub実値反映 → Codemagic署名設定 → signed IPA → Internal TestFlight upload → 実機確認依頼まで継続する。

## TestFlight最低確認項目
- 無料24問
- 月額購入
- 購入復元
- 再起動後の権利維持
- 失効/取消時の権利挙動
- 4/8/16問
- 年度別80問
- 年度×科目40問
- 苦手復習
- 中断復帰
- 機内モード
- JSONバックアップ
- 令和8年鑑定理論39・40
- 一次資料リンク
- 黒帯/セーフエリア/ホームインジケータ
- クラッシュなし

## 絶対禁止
- Apple IDを推測しない
- actual IAP Product IDを未確認でrelease有効化しない
- App Iconを再生成しない
- 公式240問を人工水増ししない
- 同じ失敗操作を3回繰り返さない
- TestFlight実機確認前にApp Store本審査へ進めない
- ユーザー明示承認なしで `Add for Review` / `Submit for Review` を実行しない

停滞時は現行NO_PROGRESSルールに従い、最新GitHub/Notion再取得 → 既完了確認 → 手法変更 → 未完了だけ再開する。
