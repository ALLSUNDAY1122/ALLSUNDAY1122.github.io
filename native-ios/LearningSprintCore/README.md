# LearningSprintCore

学びスプリント8アプリのSwiftUIネイティブ化で共有する学習ロジックです。

## 含む
- 4 / 8 / 16問の目標値
- singleChoice / multiChoice / numeric / blankSelect / declaration採点
- `わからない` の正式回答
- 誤答・わからないの苦手登録
- 3連続正解で苦手解除
- 中断セッションモデル
- 学習履歴・35日（5週間）集計
- JSONバックアップ／復元と資格間誤インポート防止
- StoreKit 2 非消耗型の権利管理
- `Product.displayPrice` のみを価格表示元とする
- pending / userCancelled / unverified / revocationで解放しない
- Golden Master v2.1の配色・明朝／ゴシック・82px進捗リング・5週間ヒートマップ部品
- VoiceOverラベルを持つ共通部品

## 含めない
- Bundle IDやApp Store Connect App IDの推測
- 資格固有の問題数・科目・合格基準
- 公式問題の権利判断
- App Store本審査の自動提出
- WKWebView

資格固有値は各アプリのNotion正本と `docs/APP_STORE_IDENTIFIERS_CANONICAL.md` を優先します。
