# 撮る単語帳 リリース状況

更新日: 2026-07-26

## 現在の段階

ChatGPT実装工程の最終確認中。Apple Visionを使うiOSネイティブOCR、OCR文字修復、表形式教材向け作問、表裏カード、両面読み上げまでコードへ実装した。

自動検査は成功しているが、独自ネイティブモジュールを含むEAS開発ビルドとiPhone実機確認、Cloudflare Workerの公開、GPT-5 nanoの実通信は未完了。このため、Claude QA用PR `#3959` は下書きのまま維持する。

## QA対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- 対象ディレクトリ: `toru-tango-mobile/`
- Web試用版: `https://allsunday1122.github.io/toru-tango/beta.html`
- 最新自動検査成功Run ID: `30220648043`

最新Runで確認済み:

- TypeScript
- ESLint
- Expo Doctor
- Expo public config
- Web作問回帰テスト
- モバイルOCR対応作問回帰テスト
- Apple Vision OCRモジュール構成
- Cloudflare Worker構文

## リリース識別情報

- アプリ名: 撮る単語帳
- Bundle ID: `com.allsunday1122.torutango`
- Version: `1.0.0`
- Build: `1`
- 対応: iPhone
- 初期版の外観: ライトモード固定
- プライバシーポリシー: `https://allsunday1122.github.io/toru-tango/privacy-policy.html`
- サポートURL: `https://allsunday1122.github.io/toru-tango/`

## 実装済み

### 単語帳

- カードの直接追加、一括追加、編集、削除
- 保存カードを表・裏として明示
- タップによる表裏反転
- 表と裏の個別読み上げ
- 重複除外
- AsyncStorage保存
- 学習履歴、正答率、連続学習、苦手カード
- JSONバックアップと復元

### 写真・OCR

- カメラ撮影と写真選択
- Apple Vision `VNRecognizeTextRequest`を使うiOSローカルネイティブモジュール
- 自動時は0度・90度・270度を比較し、日本語認識スコアが最も高い向きを採用
- 手動の左90度・右90度指定
- 日本語と英語の認識指定
- 認識結果の編集
- 単語内部の空白、罫線、明確なOCR誤認の修復
- OCR結果から教材本文への転送

Apple Vision OCRはExpo Goでは利用できない。`expo-dev-client`を含むEAS開発ビルドまたは本番ビルドで動作確認する。

### 作問

- AI作問と端末内簡易作問を別操作として実装
- AI失敗時に別モデルや簡易作問へ自動切替しない
- GPT-5 nano、reasoning effort `medium`
- JSON Schemaによる構造化出力
- 事実単位の重複除外
- 使用モデル、トークン数、応答時間、除外件数の表示
- 歴史文章、保険表OCR、重複文、情報不足文の回帰テスト
- 指定件数を満たすための低品質問題を生成しない

## AIモデル方針

最初の実通信試験は`gpt-5-nano`を使用する。nanoの品質が基準を満たさない場合だけ、同じ教材・プロンプト・JSON Schema・reasoning effortで`gpt-5-mini`と比較する。

自動切替は行わない。モデル変更はWorkerの`OPENAI_MODEL`で明示的に行う。

品質評価の正本:

- `AI_PROVIDER_RESEARCH.md`
- `AI_NANO_BENCHMARK.md`

## Claude引き渡し前の未完了項目

1. EAS development buildを作成し、Apple Visionモジュールがネイティブコンパイルできることを確認
2. iPhoneで「撮影→向き判定→OCR→修正→作問→保存→反転→読み上げ」を通しで確認
3. 今回の横向き保険表で日本語OCRと作問を確認
4. Cloudflare Workerを公開
5. Workerへ`OPENAI_API_KEY`をSecret登録
6. `EXPO_PUBLIC_AI_API_URL`を設定
7. GPT-5 nanoで3～5教材の基本実通信を確認
8. 最新headでGitHub Actionsを再度成功させる
9. PRをReady for reviewへ変更

固定20教材によるnanoの最終品質判定はClaude QAで実施してよい。Worker公開前の場合はClaudeへ渡さず、外部設定待ちとして維持する。

## 外部操作に必要な情報

- Expoアカウント／`EXPO_TOKEN`
- Apple Developer認証
- Cloudflare API TokenとAccount ID
- OpenAI APIキー

これらのSecretはコードやHTMLへ保存しない。

## Codexへ進む条件

- ClaudeのP0・P1が0件
- iPhone実機の主要導線が成功
- nano採用またはmini比較の判断が完了
- ユーザーがリリース候補を承認

現時点ではCodex、TestFlight提出、App Store審査工程へ進まない。
