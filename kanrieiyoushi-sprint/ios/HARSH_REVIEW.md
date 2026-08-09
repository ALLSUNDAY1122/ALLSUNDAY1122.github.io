# 辛口レビュー3回｜StoreKit 2＋iOS製品化

## 1回目：課金UX
指摘：起動直後のPaywall、固定価格、購入復元の隠蔽は低評価・審査リスクになる。

改善：Paywallはロック対象を押した時だけ表示。価格はStoreKit `displayPrice`取得後のみ表示・購入可能。復元はPaywallと設定の両方へ常設。無料範囲を「第1回10分類×各6問＝60問」と明記した。

## 2回目：権利状態・抜け道
指摘：購入成功だけ実装しても、pending、cancel、revocation、別端末復元、Transaction更新、JSONからのPremium途中状態復帰で権限漏れが起こる。

改善：`Transaction.currentEntitlements`、`Transaction.updates`、pending、userCancelled、revocationを実装。復元は明示操作→`AppStore.sync()`。無料版の途中復帰は60問ID内だけ許可し、Premium問題を含む途中状態は破棄してPaywallへ送る。第2・第3回、模試、詳細記録をネイティブゲートで制御する。

## 3回目：アクセシビリティ・リリース
指摘：Paywallが画面外へはみ出す、背景操作できる、閉じるボタンが小さい、Webの外部リンクがWKWebView内で失敗する、仮AppIconのままArchiveする、CIから自動提出する、といった事故余地がある。

改善：Paywall内部スクロール、背景`inert`＋スクロール固定、閉じる44pt以上、フォーカス移動・復帰を実装。一次資料リンクは許可ホストだけ外部ブラウザへ渡す。Simulator build用placeholderと正本AppIconを分離し、TestFlight/ArchiveではGoogle Drive個別PNGを必須化。Codemagicは`submit_to_testflight: false` / `submit_to_app_store: false`を固定。

## 終了条件
GitHub Actionsで600問監査、Apple/StoreKit静的監査、Privacy Manifest、XcodeGen、IAP capability、unsigned Release Simulator build、生成`.app`資産検査がPASSすること。正本AppIcon輸送とApple側設定・Sandbox/TestFlight実機購入/復元は外部ゲートとして別管理する。
