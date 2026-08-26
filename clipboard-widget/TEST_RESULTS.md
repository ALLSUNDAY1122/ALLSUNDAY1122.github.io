# Phase 0 Test Results

## CI Run 1｜2026-08-26
- Xcode 26.6 / iOS Simulator SDK 26.5
- Static audit: PASS
- XcodeGen generate: PASS
- Compile: FAIL
- 原因1: Swift 6 concurrency safetyにより `AppIntent.title/description` の `static var` が拒否された。
- 原因2: `IntentExecutionTargets` / `allowedExecutionTargets` はXcode 26.6安定版SDKに未収録だった。
- 対応: title/descriptionをimmutable化し、Beta API依存のBを安定版PoCから分離。AはApple公式の既定Widget Extension実行に戻して再compileする。

## Static / CI Run 2
- [ ] XcodeGen generate
- [ ] iPhone Simulator compile
- [ ] App target + Widget Extension link
- [ ] Widget Extension内の `UIPasteboard.general` 書き込みコードcompile
- [ ] Privacy manifest / entitlements static audit

## Device A
- [ ] Large Widget配置
- [ ] `TESTをコピー` を1回タップ
- [ ] アプリ画面へ遷移しない
- [ ] Widget内で `A / Widget Extension` のIntent実行が確認できる
- [ ] メモ等へPasteして `Widget Copy Test` と完全一致
- [ ] 3回以上繰り返して再現

判定: PENDING_DEVICE

## Device B
状態: BLOCKED_ON_STABLE_SDK

理由: `allowedExecutionTargets = .main` はApple Web上Betaで、Xcode 26.6 / iOS 26.5 SDKには型が未収録。Aが実機失敗した場合、新しい最終版SDKまたは別の安定版経路を再調査する。
