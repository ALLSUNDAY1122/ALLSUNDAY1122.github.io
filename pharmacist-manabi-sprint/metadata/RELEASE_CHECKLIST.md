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

## 新Build 5 Gate
- [ ] Static Gate PASS
- [ ] XCTest PASS
- [ ] Xcode16 Release build PASS
- [ ] iOS Preflight PASS
- [ ] main統合
- [ ] 署名IPA生成
- [ ] App Store Connect upload
- [ ] Build 5 processingState VALID
- [ ] Build 5をVersion 1.0.0へ紐付け
- [ ] Internal TestFlight配布

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
