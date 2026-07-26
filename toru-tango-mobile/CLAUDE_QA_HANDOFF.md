# Claude QA引き継ぎ書: 撮る単語帳 iOS

更新日: 2026-07-26

## 役割

Claudeは、ChatGPTが実装したリリース候補について、主要操作、UI、文字、余白、Safe Area、エラー表示、空状態、OCRと作問品質を確認する。

問題分類:

- P0: 起動不能、クラッシュ、データ損失、復元不能、主要情報漏えい
- P1: 撮影、OCR、作問、カード保存、学習、読み上げなど主要機能が完了しない
- P2: 見た目、分かりやすさ、操作感、将来改善

P0・P1の中核ロジック修正はChatGPTへ戻す。UI修正はClaudeがQAブランチへ反映してよい。TestFlight提出、署名、EAS Submit、App Store申請は行わない。

## 対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- QAブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- アプリ: `toru-tango-mobile/`
- Web試用版: `https://allsunday1122.github.io/toru-tango/beta.html`
- 仕様: `toru-tango/IOS_MIGRATION_SPEC.md`
- リリース状況: `toru-tango-mobile/RELEASE_STATUS.md`
- チェックリスト: `toru-tango-mobile/RELEASE_CHECKLIST.md`
- OCR実機計画: `toru-tango-mobile/NATIVE_OCR_TEST_PLAN.md`
- nano評価基準: `toru-tango-mobile/AI_NANO_BENCHMARK.md`

QA開始時にPRの最新head SHAを取得し、`CLAUDE_QA_REPORT.md`へ記録する。mainではなくQAブランチを対象にする。

## QA開始の前提

Claude開始前に次が完了していることを確認する。

1. EAS development buildが成功
2. Apple Vision OCRモジュールがSwiftコンパイル済み
3. iPhoneへ開発ビルドをインストール済み
4. Cloudflare Workerが公開済み
5. GPT-5 nanoで3～5教材の基本実通信済み
6. PRがReady for reviewになっている

未完了の場合はQAを開始せず、外部設定待ちまたはChatGPT工程へ差し戻す。

## 自動検査の証跡

最新成功Run ID: `30220648043`

確認済み:

- TypeScript
- ESLint
- Expo Doctor
- Expo public config
- Web作問回帰テスト
- モバイルOCR対応作問回帰テスト
- Apple Vision OCRモジュール構成
- Cloudflare Worker構文

QA中にコードを変更した場合、同workflowが再度成功することを確認する。

## 起動

Apple Vision OCRはExpo Goでは動作しない。EAS development buildを使用する。

```bash
cd toru-tango-mobile
npm install --no-audit --no-fund
npm run check
npx expo start --dev-client
```

## 重点確認

### 1. 初回起動

- 起動時の白画面、無限読み込み、例外
- 最初に「作る」が表示される
- 4タブの移動
- ノッチ、Dynamic Island、ホームインジケータとの重なり
- アイコンと起動画面

### 2. 写真・Apple Vision OCR

- カメラと写真ライブラリ
- 権限拒否時にクラッシュしない
- 写真プレビュー
- 自動向きで0度・90度・270度を比較できる
- 左90度・右90度を手動指定できる
- 横向き保険表で日本語を認識できる
- 認識結果を編集できる
- 教材本文へ転送できる
- 文字のない画像で理解できるエラーを表示する

### 3. 作問

- AI作問と端末内簡易作問が別操作
- AI失敗時に簡易作問へ自動切替しない
- OCR文字間空白と罫線ノイズを整形する
- 保険表から支払事由、限度、金額、契約年齢等を抽出する
- 歴史文章から年代、場所、名称を抽出する
- 同じ事実の一問一答と穴埋めを重複生成しない
- 不完全な語句や英語表記だけを答えにしない
- 指定件数を満たすための低品質カードを追加しない
- 生成結果を表｜裏として編集できる

### 4. GPT-5 nano

- 使用モデルが`gpt-5-nano`
- reasoning effortが`medium`
- JSON Schema形式を維持
- モデル、トークン数、応答時間、除外件数を表示
- 固定20教材を`AI_NANO_BENCHMARK.md`に従って評価
- nano品質不足時はminiへ勝手に変更せずChatGPTへ差し戻す

### 5. 単語帳・学習

- 保存カードが表と裏に分かれている
- 表と裏を個別に読み上げる
- タップで表裏を往復する
- 裏を表示するまで評価ボタンが出ない
- 「もう一度」が末尾へ戻る
- 0件、1件、大量カード時の表示
- 編集、削除、全削除

### 6. 記録・保存

- 学習履歴と統計
- 再起動後の永続化
- バックアップ保存と復元
- 不正ファイル、キャンセル、共有不可時の表示

## 初期版の確定事項

- iPhone専用
- ライトモード固定
- ログインなし
- 課金なし
- 広告なし
- クラウド同期なし
- AI初期試験モデルはGPT-5 nano
- AI失敗時の自動フォールバックなし
- 写真OCRはApple Visionで実装
- OCR結果は作問前に利用者が編集可能

## 成果物

`toru-tango-mobile/CLAUDE_QA_REPORT.md`へ次を記録する。

- 対象head SHA
- EAS Build IDと実行環境
- iPhone機種とiOSバージョン
- 実行した検査と結果
- P0、P1、P2一覧
- 再現手順
- 修正ファイルとコミット
- 再テスト結果
- nano実通信結果と使用モデル
- 未確認項目
- 「申請工程へ進行可能」または「ChatGPTへ差し戻し」の判定

## 完了条件

- P0未解決が0件
- P1未解決が0件
- P2が記録されている
- 撮影から読み上げまでの主要導線を再テスト済み
- 固定20教材のnano評価を完了
- 修正後のGitHub Actionsが成功
- ユーザーへリリース候補の承認を求められる状態
