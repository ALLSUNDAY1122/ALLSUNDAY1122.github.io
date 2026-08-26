# Phase 0 Test Results

## Static / CI
- [ ] XcodeGen generate
- [ ] iPhone Simulator compile
- [ ] App target + Widget Extension link
- [ ] Privacy manifest / entitlements static audit

## Device A
- [ ] Large Widget配置
- [ ] `TESTをコピー` を1回タップ
- [ ] アプリ画面へ遷移しない
- [ ] Widget内で `A / Widget Extension` のIntent実行が確認できる
- [ ] メモ等へPasteして `Widget Copy Test` と完全一致
- [ ] 3回以上繰り返して再現

判定: PENDING_DEVICE

## Device B（A失敗時だけ）
- [ ] `B：Main background` を1回タップ
- [ ] 明確なアプリ画面遷移がない
- [ ] Widget内で `B / Main Background` のIntent実行が確認できる
- [ ] メモ等へPasteして `Widget Copy Test - Main Background` と完全一致
- [ ] 3回以上繰り返して再現

判定: NOT_RUN_UNTIL_A_FAILS
