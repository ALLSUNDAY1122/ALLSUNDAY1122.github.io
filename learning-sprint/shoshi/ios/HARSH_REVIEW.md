# 司法書士 学びスプリント｜iOS辛口レビュー 3回

実施日: 2026-08-09
対象: iOS 1.0.0 / SwiftUI + WKWebView / StoreKit 2

## 第1回｜「課金画面が邪魔・小さいiPhoneで使えない」

### FAIL
- 初期実装では`.native-paywall-backdrop{display:grid}`がHTMLの`hidden`既定スタイルを上書きし、起動直後からPaywallが背面操作を塞ぐ実装バグがあった。
- CIスクリーンショット環境に日本語フォントがなく、目視証跡が□表示だった。
- 390×667級の画面高で、Paywall最下部の復元・Privacy/Supportまで必ず操作できる保証が弱かった。

### 修正
- `.native-paywall-backdrop[hidden]{display:none!important}`を明示。
- CIへNoto CJKを導入し、日本語で目視監査する。
- Paywallに`max-height`と内部スクロールを設定し、390×667でも画面内に収める。
- 起動直後、価格未取得、価格取得後、無料スプリント完了後を実ブラウザで撮影する。

### 再監査
- 起動直後Paywall誤表示: 解消。
- runtime `displayPrice`反映: PASS。
- 390×667 containment: PASS。

## 第2回｜「VoiceOverや背景スクロールでモーダルが壊れる」

### FAIL
- Paywall表示中も背面アプリがアクセシビリティ探索対象として残り得た。
- 背面ページのスクロールを固定していなかった。
- モーダルを閉じた後の操作位置復帰が明示されていなかった。

### 修正
- Paywall表示中は`#appShell.inert = true`。
- `html/body`のoverflowを`hidden`へ切替え、閉じる際に元値へ復元。
- 開く前のフォーカスを記録し、閉じた際に復帰。
- 開いた直後は44px以上の閉じるボタンへフォーカス。
- Escapeでも閉じられる。
- 実ブラウザ監査に`inert`、背景スクロール固定、フォーカス、390×667を追加。

### 再監査
- 背面操作隔離、スクロール固定、フォーカス: PASS条件へ追加。

## 第3回｜「買い切りなのに“無料体験”はサブスクに見える」

### FAIL
- Non-Consumable買い切りなのに「無料体験」という語だけでは、サブスクリプションの無料トライアルと誤認される余地があった。

### 修正
- ユーザー向け表現を「最初の『今日のスプリント』1回（最大8問）は無料で試せます。プレミアムは買い切りです」に変更。
- App Review Notesにも「サブスクリプションの無料トライアルではない」「Non-Consumableの買い切り」と明記。
- 価格はコードに固定せず`Product.displayPrice`のみを使用。取得不能時は購入ボタンを無効化。

### 再監査
- 課金種別、無料範囲、価格表示、復元導線の説明整合: PASS。

# 技術ゲート判定

次をRelease Gateで独立監査する。
- 210問共通validator
- Apple/TestFlight preflight
- `file://`ローカル同梱UI
- 無料8問→ロック→復元bridge→プレミアム解放
- 390×844 / 390×667
- Xcode Release Simulator build
- 生成`.app`内210問・R7午後33 `all_correct`・Privacy Manifest・Assets

# Release BLOCKER｜正本AppIcon

技術監査用Simulatorではコンパイル専用placeholderを許可するが、TestFlight/Archiveへは使用しない。

唯一の合格AppIcon:
- Google Drive: `10_司法書士試験_択一式.png`
- 1024×1024 PNG
- SHA-256: `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`

GitHub Actionsから匿名Drive URLを取得すると正本PNGではない中間レスポンスになりSHA不一致となるため、canonical icon gateは意図的にFAILする。正本PNGそのものが`learning-sprint/shoshi/ios/AppIcon.png`へ配置され、SHA一致するまでRelease PASS／署名Archive／TestFlightへ進まない。

# 最終評価

- 実装・課金UI・Xcodeビルド: 技術ゲートPASS確認後に完了扱い。
- 辛口レビュー3回: 完了。
- Release全体: **BLOCKED（正本AppIcon搬送とApple側外部設定）**。
- TestFlight実機確認: 未実施。App Store提出: 未実施。
