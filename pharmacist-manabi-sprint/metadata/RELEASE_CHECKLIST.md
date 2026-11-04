# RELEASE CHECKLIST｜薬剤師国家試験｜学びスプリント

## 製品・問題品質
- [x] Bundle ID `jp.allsunday1122.yakuzaishi`
- [x] App Store Connect App ID `6799753724`
- [x] 第111・110・109回の公式問題1,035問
- [x] 採点対象1,031問／解なし4問
- [x] 生成補充0・公式過去問のみ
- [x] SwiftUIネイティブ、WKWebViewなし
- [x] 今日のスプリント4／8／16問
- [x] 分野別は約20問セット、Daily goalから独立
- [x] 公式紙面画像は全画面・ピンチ最大6倍・ドラッグ・ダブルタップ対応
- [x] 苦手3連続正解で卒業
- [x] 中断→続きから
- [x] 35マスヒートマップ
- [x] JSON書き出し／読み込み
- [x] オフライン教材
- [x] Reduce Motion対応
- [x] Privacy Manifest：tracking false / collected data [] / accessed API []
- [x] Support／Privacy／Terms公開

## 2026-08-25 no-IAP初回公開方針
- [x] 価格：無料
- [x] アプリ内課金：なし
- [x] StoreKit実装をXcodeターゲットから除去
- [x] Paywallを除去
- [x] 購入・復元・サブスクリプション管理導線を除去
- [x] 分野別の購入ロックを除去
- [x] 模試の購入ロックを除去
- [x] 採点対象1,031問を追加購入なしで全開放
- [x] App Store説明・審査メモから旧課金文言を除去
- [x] 旧月額・買い切り商品は今回のVersionへ紐付けない

## 新TestFlight候補ビルド Gate（Build番号はCodemagic UTC timestamp採番）
- [ ] Static Gate PASS
- [ ] XCTest PASS
- [ ] Xcode16 Release build PASS
- [ ] iOS Preflight PASS
- [ ] main統合
- [ ] 署名IPA生成
- [ ] App Store Connect upload
- [ ] 新Build processingState VALID
- [ ] 新BuildがVersion 1.0.0に対応（App Review提出操作はしない）
- [ ] Internal TestFlight配布（submit_to_testflight=true）

## 2026-11-04 Q0/Q1重大欠陥修正 Gate
- [ ] 第111回問220・221の公式正誤表訂正（カプセル／1日2カプセル）を共通症例文へ反映
- [ ] 第110回問140の2026-04-01施行・現行測定方法を解説へ追記
- [ ] 第111回問77の2026-04-01適用の向精神薬政令改正を解説へ追記
- [ ] 全1,035問の公式出典URLを回答前画面に表示
- [ ] PDL1.0に基づく加工主体表示を全1,035問へ付与
- [ ] 公式正誤表・法令原典URLを該当問題の解説詳細に表示
- [ ] Static Gate / XCTest / Xcode16 Release build / iOS Preflight PASS

## TestFlight-only delivery
- [ ] Codemagic workflow `pharmacist-ios` finished
- [ ] IPA signing and App Store Connect upload success
- [ ] App Store Connect processing complete
- [ ] New build `VALID`
- [ ] Internal TestFlight group `sun` (or current internal group) available
- [ ] No App Review submission created or submitted
- [ ] User device acceptance remains for final user check

## App Store Submission Preflight
- [ ] Version Localization
- [ ] App Info Localization
- [ ] Support URL到達
- [ ] Privacy Policy URL到達
- [ ] Screenshots必須サイズ
- [ ] App Review Detail
- [ ] Age Rating
- [ ] App Privacy
- [ ] Export Compliance
- [ ] 無料価格設定
- [ ] IAPがReview Submissionへ含まれていない
- [ ] Review Submission item準備

## Human Device Acceptance
Build 4はユーザー実機確認済みだが、課金除去でBinaryが変わるためBuild 5で再確認する。
- [ ] 起動／クラッシュなし
- [ ] 今日のスプリント開始
- [ ] 分野→約20問セット開始
- [ ] 第111・110・109回の模試9区分がロックなしで開始可能
- [ ] 公式紙面画像ズーム
- [ ] 設定画面に購入・復元・プレミアム表示がない
- [ ] 機内モードで教材・図版・記録が利用可能

## 本申請
ユーザーは2026-08-25に本申請を明示承認済み。
- [ ] Human Device Acceptance完了
- [ ] Submission audit PASS
- [ ] Add for Review / Review Submission item追加
- [ ] Submit for Review
- [ ] App Store Connect状態をread-backし `WAITING_FOR_REVIEW` または現行相当状態を証拠保存

## Current instruction (2026-11-04)
本作業ではTestFlight内部配布まで。App Review用Versionへの紐付け、Review Submissionへの追加、Add for Review、Submit for Reviewは禁止。ユーザーはTestFlightの実機最終確認のみを残す。
