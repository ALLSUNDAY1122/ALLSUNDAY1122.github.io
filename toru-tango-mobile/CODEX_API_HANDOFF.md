# Codex API実装引継ぎ書｜撮る単語帳 iOS

> **2026-07-29 方針変更**：ユーザー指示によりOpenAI / GPT-5 nanoではなく、当面はGemini API無料枠の`gemini-3.5-flash-lite`を使用する。Secretは`GEMINI_API_KEY`、GitHub Actions Secretは`TORU_TANGO_GEMINI_API_KEY`とする。以降のOpenAI / nano記述は旧仕様の参考情報であり、この方針変更を優先する。

更新日: 2026-07-29

## 1. 決定した開発順

ユーザー判断により、引継ぎ順を次へ変更する。

1. ChatGPT: Safari価値検証、仕様整理、既存実装の監査
2. Codex: API実装、Worker公開、アプリ接続、実通信、開発ビルド準備
3. Claude: API実装後のUI・UX・主要導線・OCR・作問品質QA
4. Codex: ClaudeのP0・P1解消後、TestFlight・App Store申請工程

Claudeは現時点では開始しない。Codexが本書の完了条件を満たし、引継ぎ候補headを固定した後に開始する。

## 2. 対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- 作業ブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- アプリ: `toru-tango-mobile/`
- API Worker: `toru-tango/backend/`
- Safari価値検証の参照PR: `#4059`
- Safari版の最新OCR比較仕様は参照資産であり、API実装先ではない

開始時にPR `#3959` の最新head SHAを取得し、本書または作業報告へ記録する。mainへ直接コミットしない。

## 3. 現在実装済み

### iOSアプリ

- Expo / React Native構成
- iPhone専用、ライトモード固定
- カメラ撮影、写真ライブラリ選択
- Apple Vision `VNRecognizeTextRequest` のローカルExpo Module
- 0度・90度・180度・270度の自動向き比較と手動90度回転
- OCR結果の編集と教材本文への転送
- AI作問と端末内簡易作問を別操作として実装
- 表裏カード、反転学習、両面読み上げ
- AsyncStorage、履歴、苦手カード、バックアップ・復元

### API / Worker

- `toru-tango/backend/src/index.js`
- `POST /generate`
- OpenAI Responses API
- 既定モデル `gpt-5-nano`
- reasoning effort `medium`
- JSON Schemaによる構造化出力
- 入力長、件数、形式、難易度の検証
- タイムアウト、重複除外、品質指標、使用量、応答時間の返却
- `OPENAI_API_KEY`をWorker Secretとして参照
- `OPENAI_MODEL`と`OPENAI_REASONING_EFFORT`を環境変数として参照
- `EXPO_PUBLIC_AI_API_URL`をアプリ側で参照

### デプロイ

- `.github/workflows/deploy-toru-tango-ai.yml`
- Cloudflare認証情報とOpenAI APIキーをGitHub Secretsから取得
- Worker Secret登録と`wrangler deploy`
- デプロイログをArtifactへ保存

## 4. Codexの作業範囲

### A. 実装監査と安全性

- Worker、モバイルクライアント、デプロイworkflow、設定ファイルの整合性を確認する
- APIキー、Cloudflare Token、Apple認証情報をコード、ログ、PR本文へ出さない
- 入力サイズ、件数、タイムアウト、JSON不正、OpenAIエラー、空出力を明示的に処理する
- エラーログへ教材本文やSecretを出さない
- ネイティブアプリからOriginヘッダーがない場合と、許可したWeb Originの両方を確認する
- 不要な公開エンドポイントを増やさない。疎通確認が必要ならSecretやモデル情報を返さない最小限のhealth応答にする
- 自動フォールバックで別モデルや端末内作問へ切り替えない

### B. 自動テスト

最低限、次を追加または更新する。

- Workerの正常系
- 20文字未満
- 不正JSON
- 許可されないOrigin
- APIキー未設定
- OpenAI 4xx / 5xx
- タイムアウト
- JSON Schema出力の解析失敗
- 重複・不完全カードの除外
- モバイル側の未設定URL、HTTPエラー、不正レスポンス、空配列
- API失敗時に成功扱いせず、端末内作問へ自動切替しないこと

既存の`npm run check`、TypeScript、ESLint、Expo Doctor、Expo public config、OCR作問回帰、Worker構文を維持する。

### C. Cloudflare Worker公開

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `TORU_TANGO_OPENAI_API_KEY`

上記がGitHub Actions Secretsに存在する場合は、workflow_dispatchでデプロイする。存在しない場合は、Secret名と人間が設定すべき画面・手順だけを報告し、値を要求・表示しない。

デプロイ後に次を記録する。

- Workflow Run ID
- Worker URL
- デプロイ日時
- 使用モデル設定
- Secret値を含まない疎通結果

### D. アプリ接続

- `EXPO_PUBLIC_AI_API_URL`を安全な環境設定へ置く
- URL末尾の`/generate`有無を吸収する既存仕様を維持する
- 未設定、通信不能、HTTPエラー、タイムアウト、不正JSON、空出力のUIを確認する
- エラー時にユーザーがOCR本文を失わないことを確認する
- AI作問と端末内簡易作問を明確に分離する

### E. GPT-5 nano実通信

3～5教材で最初の基本実通信を行う。

最低限の教材:

- 通常の日本語説明文
- 年代・場所・名称を含む歴史文
- 金額、年齢、期間を含む表形式OCR文
- OCR空白や罫線ノイズを含む文
- 意味のある事実が少ない短文

記録する項目:

- 使用モデル
- reasoning effort
- requested / raw / accepted / duplicate / rejected
- input / output / total tokens
- elapsedMs
- 生成されたカード
- 事実誤り、意味重複、不完全な答え

nano品質が明確に不足しても、Codexの独断でminiへ変更しない。比較が必要な場合は同一教材・同一プロンプト・同一Schemaで別途記録し、ユーザー判断を求める。

### F. EAS development build

- Expo projectの初期化・リンク状態を確認する
- Bundle ID `com.allsunday1122.torutango`を維持する
- `eas build --platform ios --profile development`を実行可能な状態にする
- Apple Vision ModuleがSwiftコンパイルできることを確認する
- Build ID、Build URL、対象commit SHAを記録する
- Apple ID、二要素認証、端末登録など人間操作が必要な場合は、必要な操作だけを具体的に示して停止する

## 5. 禁止事項

- Secretをコード、Markdown、Issue、PRコメント、ログへ保存しない
- mainへ直接コミットしない
- PR `#3959`をAPI実通信・EAS開発ビルド未完了のままReadyにしない
- PR `#4059`をAPI実装先にしない
- Claudeを先に開始しない
- 課金、広告、ログイン、クラウド同期を追加しない
- GPTモデルを無断変更しない
- UIを大幅に作り直さない
- TestFlight提出、EAS Submit、App Review提出まで先行しない

## 6. 成果物

Codexは次をGitHubへ残す。

- `toru-tango-mobile/CODEX_API_REPORT.md`
- API・Worker・モバイル接続の修正コミット
- 自動テスト
- GitHub Actionsの成功Run ID
- WorkerデプロイRun IDとURL
- GPT-5 nano 3～5教材の実通信結果
- EAS development Build ID / URL、または人間操作待ちの具体的理由
- 未完了項目とSecretを含まない再現手順

`CODEX_API_REPORT.md`には必ず次を記録する。

- 開始head SHA
- 完了候補head SHA
- 変更ファイル
- 実行コマンド
- 自動テスト結果
- Worker URLとデプロイRun
- 実通信結果
- EAS Build結果
- P0 / P1 / P2
- Claudeへ渡せるかの判定

## 7. Codex完了条件

- API Secretがコード外で管理されている
- Workerが公開されている
- アプリが公開Workerへ接続できる
- GPT-5 nanoの3～5教材実通信が成功している
- API失敗時のエラー表示とデータ保持が確認できる
- 自動テストとGitHub Actionsが成功している
- EAS development buildが成功し、Apple Vision Moduleがコンパイルされている
- `CODEX_API_REPORT.md`が完成している
- 完了候補head SHAが固定されている

上記が揃った後に、PR `#3959`をClaude QA候補としてReadyにする。Claude開始時には`CLAUDE_QA_HANDOFF.md`と`CLAUDE_START_PROMPT.md`を使用する。

## 8. 人間操作待ちの扱い

外部認証やSecret設定が必要でCodexだけでは完了できない場合、作業全体を放棄しない。

1. 認証不要のコード、テスト、文書を先に完了する
2. 必要なSecret名と設定場所を列挙する
3. 値は表示・保存しない
4. 人間操作後に再開するコマンドまたはworkflow名を示す
5. `CODEX_API_REPORT.md`を「人間操作待ち」として更新する
