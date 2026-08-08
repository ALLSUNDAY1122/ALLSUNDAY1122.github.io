# 通関士｜学びスプリント

開発連番 #2。学びスプリント共通UIはFP2級 v1.3を基準とし、通関士固有差分だけを追加する。

## 現在の実装

- ホーム → 今日の12問：1タップ開始
- 続きから：1タップ復帰
- 科目別：通関業法／関税法等／通関実務
- 回答形式：singleChoice / multiChoice / blankSelect / numeric / declaration
- 択一式：選択肢タップで即時採点
- 複数選択・空欄・計算・申告書：明示的な採点操作
- 回答後：同画面で正誤 → 覚える一文 → 詳細解説 → 次問
- 誤答・わからない：苦手登録、3連続正解で解除
- 完答回数、学習履歴、途中保存、文字サイズ
- 無料／プレミアムUI、購入復元導線
- WebKit message bridgeによるStoreKit 2接続
- `auditStatus === approved` の問題だけを表示
- `contentVersion` と `lawBaseline` を保持

## コンテンツ状態

現在のGitHub Pages版はUI・状態設計を検証するための監査済み独自問題を収録した開発版。製品目標は独自学習問題480問＋申告書12セット＋直近3回分の本試験演習。

公式試験問題を収録する場合は、税関ホームページのPDL1.0、出典表示、加工表示、第三者権利を確認してから `auditStatus: approved` にする。未監査データを画面に出さない。

## iOS

`ios/project.yml` はXcodeGen用。想定Bundle IDは `jp.allsunday1122.tsukanshi`、非消耗型Product IDは `jp.allsunday1122.tsukanshi.premium`。

Mac環境では以下でXcodeプロジェクトを生成する。

```bash
cd tsukanshi-sprint/ios
xcodegen generate
open TsukanshiSprint.xcodeproj
```

生成後、Apple Developer Teamを設定し、App Store Connect側に同じProduct IDの非消耗型アプリ内課金を作成する。価格はアプリに固定値を埋め込まず、StoreKit 2の `Product.displayPrice` を表示する。

## TestFlight前の残作業

1. 製品コンテンツ480問＋申告書12セットを作成・監査
2. 第59〜57回公式問題を利用する場合のPDL1.0・第三者権利最終監査
3. App Store ConnectでBundle ID／アプリ／IAPを作成
4. XcodeGen → Archive → Sandbox購入／復元確認
5. iPhone 16で標準文字・大きい文字・オフライン・中断復帰を実機確認
6. TestFlightアップロードと処理完了確認

GitHub Pages検証URL: https://allsunday1122.github.io/tsukanshi-sprint/
