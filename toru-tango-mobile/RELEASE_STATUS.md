# 撮る単語帳 リリース状況

更新日: 2026-07-26

## 現在の段階

ChatGPTによる実装と自動検査を完了し、ClaudeによるQAへ引き渡せる状態。ただし、AI作問はGPT-5 nanoの実通信試験前であり、AI品質は未確定。

この文書はGitHub上の現在地を示す。TestFlight、ビルド処理、審査状態の正本はApp Store Connectとする。

## Claude QA対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- 対象ディレクトリ: `toru-tango-mobile/`
- 最新自動検査成功Run ID: `30202307772`
- 自動検査で確認済み: TypeScript / ESLint / Expo Doctor / Expo config / Worker構文

ClaudeはPRの最新headを対象にし、`CLAUDE_QA_HANDOFF.md`に従ってP0・P1・P2を記録する。

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

- Expo Routerによる4タブ
- カードの直接追加、一括追加、編集、削除
- 保存カードを表・裏として明示
- 学習カードをタップして表裏反転
- 表と裏の個別読み上げ
- 完全重複の除外
- AsyncStorageによる端末保存
- 全カード、苦手優先、未学習のみの学習
- 「覚えた」「もう一度」と学習履歴
- 正答率、連続学習日数、苦手カード数
- JSONバックアップと復元
- カメラ撮影と写真選択
- AI作問APIクライアント
- AI作問と端末内簡易作問を別操作として実装
- AI失敗時に別モデルや簡易作問へ自動切替しない表示
- Cloudflare Worker用AIバックエンド
- GPT-5 nanoを初期試験モデルとして設定
- reasoning effort `medium`
- JSON Schemaによる構造化出力
- factKey・質問文・回答の重複除外
- 使用モデル、トークン数、応答時間、除外件数の返却
- アプリアイコン
- `expo-splash-screen`による起動画面設定
- TypeScript、ESLint、Expo Doctor用コマンド
- GitHub Actions検査と検査ログArtifact

## AIモデル方針

初回の実通信試験は `gpt-5-nano` を使用する。nanoの品質が基準を満たさない場合だけ、同じ教材・プロンプト・JSON Schema・reasoning effortで `gpt-5-mini` と比較する。

自動切替は行わない。モデル変更はWorkerの `OPENAI_MODEL` で明示的に行う。

品質評価の正本:

- `AI_PROVIDER_RESEARCH.md`
- `AI_NANO_BENCHMARK.md`

## 2026-07-26の主な修正

- モバイル側の `text` とWorker側の `source` のAPI不一致を解消
- OpenAI Responses APIをJSON Schema出力に変更
- OpenAIリクエストを `store: false` に変更
- Workerに入力サイズ制限、タイムアウト、アクセス元確認を追加
- AsyncStorageとバックアップ復元のデータ検証を強化
- EAS設定をNotion標準手順に合わせ、`appVersionSource: local`、`credentialsSource: remote` に変更
- ライトモード固定とステータスバー表示を明示
- 1024pxのPNGアイコンと起動画面設定を追加
- 表裏カード、タップ反転、両面読み上げを追加
- AIの意味重複除外と品質メタデータを追加
- 標準モデルをGPT-5 miniからGPT-5 nanoへ変更
- 最新検査Run `30202307772` が成功

## 未完了・外部操作待ち

- Cloudflare Workerの公開
- `OPENAI_API_KEY` のCloudflare Secret登録
- `EXPO_PUBLIC_AI_API_URL` の設定
- GPT-5 nanoによる固定20教材の実通信試験
- nanoの事実誤り、意味重複率、編集不要率、実費の記録
- nanoが不合格だった場合のmini比較
- 写真からのOCR
- iPhone実機での主要操作・読み上げ確認
- ClaudeによるUI・動作QA
- P0・P1を0件にする修正
- 人間によるリリース候補承認
- EAS projectId設定
- EAS production buildとSubmit

AIバックエンド未公開時でも、端末内簡易作問は利用できる。ただしAI失敗時には自動実行せず、利用者が別ボタンから明示的に実行する。

## 機能凍結条件

次の条件をすべて満たしたコミットをリリース候補として固定する。

1. GitHub Actionsの全検査が成功
2. GPT-5 nanoの実通信試験結果を記録
3. AI品質が採用基準を満たすか、miniへ切り替える判断が完了
4. ClaudeのP0・P1が0件
5. iPhone実機で主要導線が完了
6. ユーザーが明示的に承認

現在はClaude QAおよびnano実通信試験前であり、Codexへの申請引き渡し前である。
