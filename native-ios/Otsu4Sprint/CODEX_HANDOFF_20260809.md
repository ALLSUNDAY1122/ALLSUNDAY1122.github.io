# Codex引継ぎ｜危険物取扱者 乙種4類｜学びスプリント

更新: 2026-08-09 12:22 JST

## 0. 最優先ルール
この作業はNotion正本とGitHub正本に従う。

Notion:
1. AIアプリ開発 標準手順 v2.2
   https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
2. 申請手順
   https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
3. 学びスプリント UI要件定義テンプレ v2.1 Golden Master
   https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
4. 乙4 UI/開発正本
   https://app.notion.com/p/3b609c10697d81a09a51e63dc675295f

GitHub:
- repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- product branch: `feat/otsu4-360-productization`
- product PR: `#4069`
- PRはTestFlight実機確認完了までDraftを維持する。
- App Store本審査への自動提出は禁止。

## 1. 現在地
申請前Release Gateまで完了済み。

`native-ios/Otsu4Sprint/RELEASE_CI_STATUS.md`
- Result: PASS
- Sync latest main: success
- Content audit / 360 questions: success
- Native resource preparation: success
- Runtime decode / sprint 4・8・16 / mock 3×35: success
- SwiftUI + StoreKit typecheck: success
- Xcode Release Simulator build: success
- Bundle JSON + PrivacyInfo + Assets.car: success
- Production App Store submit: NOT EXECUTED

## 2. 問題バンク
contentVersion: `otsu4-2026-08-product-v2`

総数 360問:
- 法令 144
- 物理・化学 96
- 性質・消火 120

厳格監査:
- 完全同一問題 0
- learningObjective重複 0
- 解説パッケージ重複 0
- anti-padding 0
- errors 0
- warnings 0

権利方針:
- 消防試験研究センターの公式過去問本文を転載しない。
- 近接言い換えもしない。
- 過去問は論点・頻度分析のみ。
- 問題文、選択肢、解説は一次資料から独自作成。

法令基準:
- 消防法: 2025-06-01施行版
- 危険物の規制に関する政令: 2026-04-04施行版
- 危険物の規制に関する規則: 2026-04-04施行版
- 監査日: 2026-08-09

## 3. UI正本 v2.1
旧12問・3タブ仕様は廃止済み。

現在の必須仕様:
- 標準8問
- 設定4 / 8 / 16問
- ホーム / 模試 / 記録 / 設定の4タブ
- 生成り紙面 + 藍 / 朱 / 緑 / 金
- 問題・結果の明朝系主見出し
- 28pxグリッド背景
- 82px進捗リング
- 回答後の○/×演出
- `ここだけ覚える`
- `わからない`
- 苦手は誤答/不明で登録、3連続正解で解除
- 中断復帰
- 5週間ヒートマップ
- 試験日 / 残日数 / 必要ペース
- JSONバックアップ / 復元

模試:
- 3セット
- 各35問 / 120分
- 法令15 / 物化10 / 性質消火10
- 3セット間ID重複なし
- 模試中は即時正誤を表示しない
- startedAt基準で中断復帰後も時間を戻さない
- 終了後に3科目それぞれ60%以上を判定

## 4. Native iOS
場所: `native-ios/Otsu4Sprint/`

主要ファイル:
- `project.yml`
- `Info.plist`
- `PrivacyInfo.xcprivacy`
- `prepare-ios.sh`
- `Otsu4ContentStore.swift`
- `Otsu4LearningStore.swift`
- `Otsu4StudySession.swift`
- `Otsu4LearningView.swift`
- `Otsu4PurchaseStore.swift`
- `Otsu4PaywallView.swift`
- `Otsu4DesignSystem.swift`
- `RELEASE_CHECKLIST_V2.md`
- `RELEASE_CI_STATUS.md`

Bundle ID:
`jp.allsunday1122.otsu4`

Version:
`1.0.0`

StoreKit 2:
- non-consumable
- Product ID: `jp.allsunday1122.otsu4.premium`
- free: 72問
- premium: 360問 + 模試3回等
- verified transactionのみ解放
- `Transaction.currentEntitlements`
- `Transaction.updates`
- 復元は明示ボタンから `AppStore.sync()`
- pending / cancelled / unverifiedで解放しない

## 5. App Icon
壊れたbase64原本は削除済み。
`prepare-ios.sh` が1024x1024 RGB/no-alpha PNGを決定的に生成する。
Xcode Release Simulator BuildでAssets.car同梱までPASS済み。

## 6. CI
mainへ先行反映済み:
- `.github/workflows/otsu4-content-audit.yml`
- `.github/workflows/otsu4-native-typecheck.yml`
- `.github/workflows/otsu4-xcode-build.yml`
- Otsu4 Release Foundation Lint

PR #4080で基盤をmainへマージ済み。

製品PR #4069の実動結果:
- Content Audit PASS
- Native Typecheck PASS
- Xcode Release Simulator Build PASS

## 7. Codemagic
main `codemagic.yaml` に `otsu4-ios` workflowを反映済み。

方針:
- distribution_type: app_store
- bundle_identifier: `jp.allsunday1122.otsu4`
- XcodeGenでプロジェクト生成
- 監査済360問JSONをbundleへ入れる
- App Store signing profilesを適用
- `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`
- `submit_to_app_store: false`

注意:
- `submit_to_testflight: false` は内部TestFlight専用。Beta App Reviewへ自動提出しない。
- 本審査は絶対に自動提出しない。
- App Store Connect API key / certificate / profile等の秘密情報をGitHubへ置かない。

## 8. 公開ページ
PR #4080でmainへ反映済み:
- Support page
- Privacy Policy

HTTP 200の外部到達確認だけ未確認。
このChatGPT環境では外部DNS制限があり確認不能だったため、Codex側で可能なら実URLをcurl等で確認する。

## 9. Apple側で固定する値
詳細: `native-ios/Otsu4Sprint/APPLE_SETUP_VALUES.md`

App:
- Name: `危険物乙4｜学びスプリント`
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.otsu4`
- SKU: `otsu4-sprint-ios-001`
- 本体価格: 無料

IAP:
- Type: Non-Consumable
- Reference Name: `乙4 プレミアム 買い切り`
- Product ID: `jp.allsunday1122.otsu4.premium`
- Display Name: `乙4 プレミアム`
- 価格候補: ¥980

課金方針はNotion申請手順に従い、乙4は買い切り中心で進行する。

## 10. 次にCodexが行うこと
Apple/Codemagic認証情報が利用可能なら、以下を順に処理する。

1. Support / Privacy公開URLのHTTP 200確認。
2. Apple DeveloperでExplicit App ID `jp.allsunday1122.otsu4` の存在確認。無ければ作成。
3. App Store Connectでアプリレコードの存在確認。無ければ固定値で作成。
4. 非消耗型IAP `jp.allsunday1122.otsu4.premium` の存在確認。無ければ作成し価格設定。
5. Paid Apps Agreement / Tax / Banking等の必要状態を確認。
6. App Privacy回答と `PrivacyInfo.xcprivacy` / 実装を照合。
7. 年齢区分回答を準備。
8. Codemagic App Store Connect integration / code signingを確認。
9. 署名付きArchive/IPAを作成。
10. App Store Connectへアップロードし、TestFlight内部テストへ載せる。
11. TestFlight反映後、PR #4069とNotionへbuild番号・日時・状態を記録。

## 11. TestFlight実機監査
ユーザーのiPhoneで確認が必要。

必須:
- 起動
- 8問学習
- 4問 / 8問 / 16問設定
- `わからない`
- 苦手登録
- 苦手3連続正解解除
- 続きから
- 模試3セット
- 35問 / 120分
- 模試中の正誤非表示
- 記録 / 5週間ヒートマップ
- 試験日 / 残日数 / 必要ペース
- JSONバックアップ / 復元
- Premium購入成功
- 購入キャンセル
- pending
- 復元
- 再インストール後entitlement
- 大きい文字で切れ・重なり・横スクロールなし
- 最終スクリーンショット

## 12. STOP条件
以下はユーザーの明示承認前に行わない。

- App Store本審査への提出
- PR #4069の最終マージ
- `submit_to_app_store: true` への変更
- Beta App Reviewへの不要な自動提出
- Product ID / Bundle IDの変更
- 360問の再生成による内容差し替え
- UI Golden Master v2.1からの独自逸脱

## 13. 作業時の判断ルール
- 質問で止まる前に、GitHub / Notion / Apple設定から解決できるか確認する。
- 既存正本に答えがある場合はユーザーへ再質問しない。
- 修正後は必ず該当CIを通す。
- 法令・問題を変更した場合はContent Auditを必ず再実行。
- StoreKitを変更した場合はNative Typecheck + Sandbox確認を必ず再実行。
- UIを変更した場合はGolden Master v2.1との差分理由を記録。
- TestFlightまでは自律的に進めてよいが、本審査送信はSTOPする。

## 14. 完了条件
Codex側の引継ぎ完了は次を満たした時点。
- 署名IPA生成成功
- TestFlight内部テストへ反映
- build番号記録
- Apple/IAP設定記録
- GitHub PR #4069更新
- Notion台帳更新
- ユーザーへ実機確認項目を提示

その後はユーザーの実機確認結果を受け、必要修正を行い、最終承認を待つ。
