# Codex引き継ぎ｜開発連番#12 不動産鑑定士試験・短答式｜学びスプリント

更新日: 2026-08-14

## 役割

このブランチの開発をChatGPTからCodexへ引き継ぐ。

Codexは、ユーザー確認が本当に必要な工程まで自律的に進めること。単なる「次」待ち、同じ失敗操作の反復、既に完了した工程のやり直しは禁止する。

作業前に必ずGitHubの最新HEAD、PR #4138、Notion正本を再取得し、この文書より新しい実状態があれば実状態を優先する。

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

- アプリ台帳ページ: `3b609c10-697d-813f-8d55-fa0735c1e502`
- 対象アプリ識別情報正本: `3b709c10-697d-8138-a352-c422d4dd5c47`
- 標準手順: 現行最上位版を再取得して適用
- 申請手順: `3b009c10-697d-81eb-a325-f86d8af55481`

古い記述より現行Notion正本を優先する。

## 現在の完成状態

### 問題

- 国土交通省公表の令和8・7・6年短答式をcanonical化済み
- 3年度 × 80問 = 240問
- 各年度: 行政法規40 + 鑑定理論40
- 全問5択
- ID重複0
- 人工水増し0
- 第三者権利要確認0
- 令和8年 鑑定理論39・40の表は数値関係を保持して文章再構成し監査PASS
- production payload: `KanteishiShortAnswer/Resources/questions.production.json`

### アプリ

SwiftUI native / iPhone専用 / iOS 17+ / portrait。

実装済み:
- 今日のスプリント 4/8/16問
- 年度別80問模試
- 年度×科目40問演習
- 苦手 / わからない
- 3連続正解で苦手解除
- 中断復帰
- 学習履歴
- 5週間ヒートマップ
- JSONバックアップ
- Application Support端末内保存
- オフライン学習
- 国土交通省一次資料リンク

### 課金アクセス

現行仕様:
- 無料: canonical 240問のうち24問
- プレミアム: 全240問、年度別80問、年度×科目40問
- 方式: 自動更新サブスクリプション（月額）
- 日本向け基準価格: 200円
- 初回無料期間: なし
- 価格表示: StoreKit `Product.displayPrice` のみ
- StoreKit 2
- verified transaction + Product ID一致 + 未取消のみ権利付与
- 購入復元実装済み

planned Product ID:
`jp.allsunday1122.kanteishishortanswer.monthly200`

重要: actual Product IDはApp Store Connectの実登録値だけを正本化する。未登録状態で推測値をrelease buildへ有効化しない。

### Apple識別情報

確定:
- Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- Codemagic profile名: `kanteishishortanswer_appstore`

未確定:
- App Store Connect数値Apple ID: Apple発行待ち。絶対に推測しない。
- actual subscription Product ID: App Store Connect実登録後に記録。

### App Icon

正本:
- Google Drive: `12_不動産鑑定士試験_短答式.png`
- Drive ID: `1wnnkFkere2-9OKXYSG3T_bS6NqS3xWMX`
- SHA-256: `679f3493524dd2cf71126303c998b15395c70ff19f224d158a760ee3c2a395f1`
- 1024×1024 RGB PNG

GitHubへ実バイナリ統合済み:
`kanteishi-shortanswer-sprint/ios/KanteishiShortAnswer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

旧Base64分割搬送方式は廃止済み。復活させない。

### CI

直近で以下をPASS確認済み:
- Kanteishi Short Answer: core/content、XcodeGen、SwiftUI typecheck、Simulator build、XCTest、XCUITest、clean install/launch、full-screen visual gate
- Official 240: PASS
- AppIcon Contract / SHA監査: PASS

Codexは必ず最新HEADでActionsを再取得し、古いrun番号を盲信しない。

## Codemagic

root `codemagic.yaml` に `kanteishi-shortanswer-ios` workflowを追加済み。

重要設定:
- distribution_type: app_store
- bundle_identifier: `jp.allsunday1122.kanteishishortanswer`
- AppIcon SHA監査
- production 240問監査
- `PREMIUM_PRODUCT_ID` が未設定ならrelease buildを明示FAIL
- `xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'`
- `submit_to_testflight: true`
- `submit_to_app_store: false`

App Store本審査への自動提出は永久に禁止。ユーザー明示承認までは `submit_to_app_store: false` を維持する。

## 次の工程

現在は **Pre-TestFlight / App Store Connect HUMAN GATE**。

必要な実値:
1. App Store Connectで新規Appを作成
2. Apple発行の数値App IDを取得
3. 月額自動更新サブスクリプションを作成
4. actual Product IDを取得

ユーザー側でApp Store Connectのログイン/2FAが必要な場合だけ人間へ戻す。

ユーザーからApple ID実値とactual Product IDが渡されたら、Codexは確認質問を増やさず以下を続行する:
1. Notion識別情報正本へ実値記録
2. GitHub release docsへ実値反映
3. Codemagic環境変数/署名設定を実値で確定
4. signed Archive / IPA作成
5. App Store Connectへbuild upload
6. Internal TestFlight配布
7. TestFlight Notes / build情報更新
8. ユーザーへ実機確認を依頼

## TestFlight実機確認項目

最低限:
- 無料24問
- 月額購入
- 購入復元
- 再起動後の権利維持
- 失効/取消時の権利挙動
- 4/8/16問スプリント
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

- App Store Connect数値Apple IDを推測しない
- actual IAP Product IDを未確認でrelease有効化しない
- App Iconを再生成・似せて作り直さない
- 公式240問を人工的に水増ししない
- 既にPASS済み工程を理由なく最初からやり直さない
- 同じ失敗操作を3回繰り返さない
- TestFlight実機確認前にApp Store本審査へ進めない
- ユーザー明示承認なしで `Add for Review` / `Submit for Review` を実行しない

## 停滞時ルール

同じ操作や同じエラー対処が3回続いて新しい成果物・commit・CI結果・状態遷移がない場合はNO_PROGRESSと判定する。

その場合:
1. 最新GitHub / Notionを再取得
2. 既完了状態を確認
3. 手法を変更
4. 未完了工程だけ再開
5. 人間操作が本当に必要なときだけユーザーへ返す

## Codexへの最初の指示

この文書、PR #4138、Notion正本、最新GitHub Actionsを確認し、現状態を再監査してください。

人間操作なしで進められる未完了工程が残っていれば、その場で完了まで進めてください。App Store Connectログイン/2FA、Apple発行App IDの取得、actual Product ID登録など本人操作が必要な地点に到達した場合のみ、ユーザーへ必要操作を最小限で具体的に提示して停止してください。
