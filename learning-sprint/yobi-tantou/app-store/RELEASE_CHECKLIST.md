# Release Checklist｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-14
現在判定: `BLOCKED / DEVELOPMENT`
標準手順: v2.4

## A. 正本・教材
- [x] Notion開発正本を作成し台帳へ接続
- [x] Golden Master v2.1を適用
- [x] 純SwiftUI・WebView 0
- [x] R6-R8公式構成・法令基準日監査
- [x] R6/R7公式採点canonical
- [x] 公式一般教養130題fail-closed権利トリアージ
- [x] 独自模試1 139/139完成（法律95＋一般教養44）
- [ ] 独自模試2 139/139完成（14/139）
- [ ] 独自模試3 139/139完成（14/139）
- [ ] 3回分417題完成（167/417、残り250）
- [ ] 417題の重複・高類似・正答・根拠・水増し0
- [ ] Native正式417題統合監査PASS

## B. 品質基盤
- [x] Native seed 42問release_passed
- [x] 模試1法律追加81問release_passed
- [x] 模試1一般教養44題self-authored deterministic release_passed
- [x] e-Gov exact-date / answer / distractor / global uniqueness / editorial quality
- [x] 一般教養の正答再計算監査
- [ ] 模試2・3残り250題

## C. Native / StoreKit
- [x] 4タブ、8問スプリント、分野別、苦手、わからない、再開、記録、JSON backup
- [x] Bundle ID `jp.allsunday1122.yobishikentantou`
- [x] Auto-Renewable Subscription（月額200円基準）
- [x] planned Product ID `jp.allsunday1122.yobishikentantou.monthly`
- [x] StoreKit `displayPrice`のみ
- [x] v2.4 Source Contract #361 PASS
- [x] v2.4 Swift Validation #32: XCTest / XCUITest / unsigned Release build PASS

## D. AppIcon
- [x] Drive正本 `11_司法試験予備試験_短答式.png`
- [x] 1024×1024 / SHA-256固定
- [ ] signed Releaseで実バイト検証

## E. App Store Connect / TestFlight
- [ ] App Store Connect Apple ID実発行値
- [ ] planned IAPを実登録・200円/月設定
- [ ] runtime Product ID設定
- [ ] subscription group実値
- [ ] signing profile
- [ ] signed IPA
- [ ] Internal TestFlight
- [ ] Sandbox purchase/restore/pending/cancel/expiry

## F. 外部審査
- [ ] ユーザー明示承認
- [ ] External Beta App Review（必要な場合）
- [ ] App Store本審査

**ユーザー承認前に外部審査へ提出しない。**
