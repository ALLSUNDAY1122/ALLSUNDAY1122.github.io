# 撮る単語帳 リリース状況

更新日: 2026-07-26

## 現在の段階

ChatGPTによる実装と自動検査を完了し、ClaudeによるQAへ引き渡せる状態。

この文書はGitHub上の現在地を示す。TestFlight、ビルド処理、審査状態の正本はApp Store Connectとする。

## Claude QA対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- 対象ディレクトリ: `toru-tango-mobile/`
- 自動検査成功Run ID: `30199401934`
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
- 完全重複の除外
- AsyncStorageによる端末保存
- 全カード、苦手優先、未学習のみの学習
- 読み上げ
- 「覚えた」「もう一度」と学習履歴
- 正答率、連続学習日数、苦手カード数
- JSONバックアップと復元
- カメラ撮影と写真選択
- AI作問APIクライアント
- AI接続失敗時の端末内簡易作問
- Cloudflare Worker用AIバックエンド
- アプリアイコン
- `expo-splash-screen`による起動画面設定
- TypeScript、ESLint、Expo Doctor用コマンド
- GitHub Actions検査と検査ログArtifact

## 2026-07-26の修正

- モバイル側の `text` とWorker側の `source` のAPI不一致を解消
- OpenAI Responses APIをJSON Schema出力に変更
- OpenAIリクエストを `store: false` に変更
- Workerに入力サイズ制限、タイムアウト、アクセス元確認を追加
- AsyncStorageとバックアップ復元のデータ検証を強化
- EAS設定をNotion標準手順に合わせ、`appVersionSource: local`、`credentialsSource: remote` に変更
- ライトモード固定とステータスバー表示を明示
- 1024pxのPNGアイコンと起動画面設定を追加
- PR単位で全検査を実行し、Run `30199401934` が成功

## 未完了・外部操作待ち

- Cloudflare Workerの公開
- `OPENAI_API_KEY` のCloudflare Secret登録
- `EXPO_PUBLIC_AI_API_URL` の設定
- AI作問の実通信試験
- 写真からのOCR。初回TestFlightでは非対象候補
- iPhone実機での主要操作確認
- ClaudeによるUI・動作QA
- P0・P1を0件にする修正
- 人間によるリリース候補承認
- EAS projectId設定
- EAS production buildとSubmit

AIバックエンド未公開時も、端末内簡易作問へ切り替わるため、アプリはクラッシュせず主要なカード作成・学習を継続できる設計とする。

## 機能凍結条件

次の条件をすべて満たしたコミットをリリース候補として固定する。

1. GitHub Actionsの全検査が成功
2. ClaudeのP0・P1が0件
3. iPhone実機で主要導線が完了
4. ユーザーが明示的に承認

自動検査は完了した。現在はClaude QA前であり、Codexへの申請引き渡し前である。
