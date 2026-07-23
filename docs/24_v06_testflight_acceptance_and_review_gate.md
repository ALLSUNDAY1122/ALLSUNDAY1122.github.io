# AI引継ぎ帳 v0.6 TestFlight受入テスト・App Review提出ゲート

作成日：2026年7月24日

## TestFlight運用

初回は内部テストを使用する。内部テスターはApp Store Connectユーザーから追加し、内部グループへVersion 0.6.0 / Build 6を割り当てる。

外部テストを開始する場合は、Beta App DescriptionとFeedback Emailを設定する。Feedback Emailは公開・テスター連絡用の専用メールを推奨し、会社メールを使う場合は公開範囲と継続利用可否を確認する。

## 受入テスト環境

- 実機：iPhone 16
- 配布：TestFlight
- 対象：Version 0.6.0 / Build 6
- 通信状態：通常接続と機内モード
- テストデータ：架空データのみ
- 証跡：スクリーンショット、画面録画、保存JSON、App Store ConnectのBuild画面

## 不具合重大度

### P0 致命的

- 起動不能、頻繁なクラッシュ、フリーズ
- データ消失、別プロジェクトへのデータ混入
- バックアップ復元による既存データ破壊
- App Privacy回答と異なる外部送信
- 認証情報や秘密情報の意図しない露出

P0が1件でもあれば提出不可。

### P1 重大

- プロジェクト、タスク、ログ、引継ぎ、保存・復元など主要機能が完了できない
- 再起動後に主要データまたは設定が保持されない
- OS共有やファイル選択からアプリへ戻れない
- iPhone 16で主要ボタンが押せない、本文が読めない
- App Store説明にある機能が実機で動作しない

P1が1件でもあれば提出不可。

### P2 軽微

- 誤字、余白、軽微な表示ずれ
- 回避可能でデータ、主要操作、審査説明へ影響しない問題

P2は内容と回避策を記録し、誤解を招く表示や重大なアクセシビリティ問題でなければ提出判断可能。

## App Review提出のGo条件

- 受入テストCSVの「必須」「提出前」が全件合格
- P0 = 0、P1 = 0
- 未解決P2は一覧化され、主要操作へ影響しない
- Build UploadsがComplete
- Completeに警告がある場合は内容確認済み
- Bundle ID `jp.allsunday.aihandoverlog`
- Version `0.6.0`
- Build `6`
- iPhone 16実機確認済み
- Privacy URLとSupport URLがHTTPSで一般公開
- スクリーンショット5枚に文字化け・透明部分なし
- App Privacy「収集なし」が実装と一致
- 年齢制限回答が実装と一致
- App Review Notesが最新実装と一致
- App Review連絡先が有効
- ログイン不要として提出
- 価格無料、初回配信地域日本、手動リリース

## No-Go条件

- 必須テスト未実施
- P0またはP1が残る
- BuildがProcessing、Failed、または意図しないバージョン
- 公開URLが404、アクセス制限、仮文面
- メタデータと実装の不一致
- 審査担当者が主要機能へ到達できない
- プライバシー回答に不明点がある
- 契約未同意
- App Store Connect必須項目が未入力

## App Store Connect提出順序

1. TestFlightでBuild 6がCompleteであることを確認
2. 内部グループへBuildを追加
3. What to Testを入力
4. iPhone 16へインストール
5. 全受入テストを実施
6. 不具合修正時はBuild番号を上げて再テスト
7. App Store版Version 0.6.0へ正しいBuildを選択
8. 説明、キーワード、URL、スクリーンショットを確認
9. App Privacy、年齢制限、価格・配信地域を確認
10. App Review連絡先とNotesを確認
11. Add for Review
12. Draft Submissionを確認
13. Submit for Review

## Build処理の判断

- Processing：Apple側処理中
- Failed：詳細を確認して修正し再アップロード
- Complete：テスト可能。警告がある場合は内容確認
- Processingが24時間を超える場合：Feedback AssistantまたはApple Developer Supportへ問い合わせ

## App Review向け確認手順

1. 初回説明を完了
2. デモプロジェクトを確認
3. 現在地を確認
4. タスク追加・編集・状態変更
5. ログ登録
6. 引継ぎ文生成・コピー・OS共有
7. 設定とプライバシー
8. JSONバックアップ保存・読込

特別なテストアカウント、外部機器、バックエンドは不要。
