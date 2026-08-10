# 危険物乙4｜標準手順 v2.2 / 申請手順 リリースチェック

更新: 2026-08-10

> 2026-08-10のNative・StoreKit・XCTest・Dynamic Type・署名設定変更により、2026-08-09のRelease Gate PASSは失効。以下の強化ゲートを最新headで再PASSするまでTestFlightへ進めない。

## A. 受入・専門監査
- [x] 360問コンテンツ監査: 360 / 法令144 / 物化96 / 性消120
- [x] 完全重複 0
- [x] learningObjective重複 0
- [x] 解説パッケージ重複 0
- [x] anti-padding 0
- [x] 法令基準日と監査日を分離
- [x] 公式過去問本文を転載・近接言い換えしない
- [x] regulation watcher対象へ乙4一次資料を追加
- [x] StoreKit 2: 購入、currentEntitlements、Transaction.updates、復元導線
- [x] pending / cancelled / unverified / revocation / upgradedでPremiumを解放しない

## B. UI正本 v2.1 Golden Master
- [x] 標準8問、4 / 8 / 16問設定
- [x] ホーム / 模試 / 記録 / 設定の4タブ
- [x] 生成り紙面、藍、朱、緑、金
- [x] 問題・結果の明朝系主見出し、操作文字ゴシック
- [x] 28pxグリッド背景
- [x] 82px進捗リング
- [x] ○/×の朱色オーバーレイ
- [x] 「ここだけ覚える」ブロック
- [x] `わからない`正式回答
- [x] 誤答 / わからないを苦手登録
- [x] 苦手3連続正解解除
- [x] 続きから再開
- [x] 記録 / 分野別 / 5週間ヒートマップ
- [x] JSONバックアップ / 復元
- [x] 試験日 / 残日数 / 必要ペース
- [x] 模試3回、各35問・120分、15 / 10 / 10、3セット相互重複なし
- [x] 模試中は即時正誤を表示しない
- [x] 模試タイマーはstartedAt基準
- [x] Text Styleベースへ移行しDynamic Type対応を強化

## C. 2026-08-10 強化品質ループ
- [x] XCTest Unit target追加
- [x] XCTest UI target追加
- [x] わからない→苦手登録→3連続正解解除テスト作成
- [x] 誤答で連続正解カウントをリセットするテスト作成
- [x] JSONバックアップ往復テスト作成
- [x] 模試startedAt復帰タイマーテスト作成
- [x] 各科目60%合格 / 1科目未達FAILテスト作成
- [x] 4タブ / 通常問題 / わからない UI smoke test作成
- [x] VoiceOver操作要素の空ラベル検査を追加
- [x] 横方向はみ出し検査を追加
- [x] accessibility3文字サイズ検査を追加
- [x] 小型 / 大型iPhone Simulatorの2サイズ実行をCIへ追加
- [ ] Unit XCTest latest head PASS
- [ ] UI XCTest small iPhone PASS
- [ ] UI XCTest large iPhone PASS
- [ ] accessibility3横はみ出しなし PASS

## D. Xcode / Bundle / 識別情報
- [x] SwiftUI native + XcodeGen
- [x] Apple Team ID `MN3D2ZM44N`
- [x] Bundle ID `jp.allsunday1122.otsu4`
- [x] App Store Connect App ID `6799755566` を申請正本へ記録
- [x] Version `1.0.0` / Build `1` をtargetへ明示
- [x] `Info.plist`
- [x] `PrivacyInfo.xcprivacy`
- [x] 監査済み360問JSONをCopy Bundle Resourcesへ固定
- [x] Release Simulator BuildでJSON / PrivacyInfo / Assets.car同梱検査
- [x] CIでCFBundleIdentifier / ShortVersion / Buildを正本値と厳密照合
- [ ] 最新headのRelease Simulator Build再PASS

## E. App Icon
Notion「申請手順」に従い、学びスプリントの自動生成アイコンを完成品として使用しない。

正本:
- Google Drive: `01_危険物取扱者_乙種4類.png`
- file ID: `10B_svZxlg80KfV61atBj4_sBkMTndFwS`
- 1024 x 1024 / RGB / no alpha
- SHA-256: `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d`

- [x] 正本PNG取得・寸法・色形式・SHA確認
- [x] CIへ正本SHA強制チェック追加
- [ ] 正本PNGそのものをAsset Catalogへ固定
- [ ] 正本SHA一致でCI PASS

## F. App Store Connect / 課金
- [x] App Store Connect App ID正本: `6799755566`
- [x] IAP Product ID正本: `jp.allsunday1122.otsu4.premium`
- [x] アプリ内価格は `Product.displayPrice` のみ、固定価格記載を削除
- [ ] IAPのApp Store Connect登録状態を本人認証環境で確認
- [ ] Paid Apps Agreement等の必要契約状態を確認
- [ ] App Privacy回答を実装と最終照合
- [ ] 年齢区分回答

## G. Codemagic / Internal TestFlight
- [x] workflow `otsu4-ios`
- [x] canonical profile `otsu4_appstore` を指定
- [x] Team ID / Bundle ID / App Store IDをpreflightで厳密照合
- [x] `testFlightInternalTestingOnly: true`
- [x] `submit_to_testflight: false`
- [x] `submit_to_app_store: false`
- [ ] `otsu4_appstore` と組み合わせる実在Apple Distribution証明書をCodemagicで確認
- [ ] 署名付きArchive / IPA
- [ ] Validate / App Store Connect App ID `6799755566` へアップロード
- [ ] Internal TestFlightへBuild反映

## H. 実機チェックポイント
- [ ] iPhoneでInternal TestFlight Buildを起動
- [ ] 4 / 8 / 16問
- [ ] `わからない`
- [ ] 苦手3連続解除
- [ ] 中断復帰
- [ ] 模試3回
- [ ] 記録 / 5週間ヒートマップ
- [ ] JSONバックアップ / 復元
- [ ] 購入成功 / cancel / pending / restore / 再インストール後entitlement
- [ ] VoiceOver
- [ ] 大きい文字
- [ ] 横スクロールなし
- [ ] 最終スクリーンショット

## 現在のRelease blocker
1. 最新headのUnit / UI XCTest最終PASS未確認。
2. Google Drive正本App IconをAsset Catalogへ同一資産として固定できていない。
3. Codemagic profile `otsu4_appstore` に対応するApple Distribution証明書Reference nameが正本未記載。推測禁止。
4. 上記完了後の署名IPA / Internal TestFlight実機監査が未実施。

## STOP条件
- App Store本番審査への自動提出禁止。
- ユーザーの最終承認前は `submit_to_app_store: false` を維持する。
- Internal TestFlight実機確認前にPR #4069を最終マージしない。
- Bundle ID / App Store Connect App ID / IAP / profile / 資格名を変更しない。
