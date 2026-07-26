# 撮る単語帳 リリース状況

更新日: 2026-07-26

## 現在の段階

ChatGPTによる仕様・実装段階。ClaudeによるQA開始前。

この文書はGitHub上の現在地を示す。TestFlight、ビルド処理、審査状態の正本はApp Store Connectとする。

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
- TypeScript、ESLint、Expo Doctor用コマンド
- GitHub Actions検査定義

## 2026-07-26の修正

- モバイル側の `text` とWorker側の `source` のAPI不一致を解消
- OpenAI Responses APIをJSON Schema出力に変更
- OpenAIリクエストを `store: false` に変更
- Workerに入力サイズ制限、タイムアウト、アクセス元確認を追加
- AsyncStorageとバックアップ復元のデータ検証を強化
- EAS設定をNotion標準手順に合わせ、`appVersionSource: local`、`credentialsSource: remote` に変更
- ライトモード固定とステータスバー表示を明示

## 未完了・外部操作待ち

- GitHub Actionsの成功結果確認
- WindowsまたはCIでの依存導入後の `npm run check`
- Cloudflare Workerの公開
- `OPENAI_API_KEY` のCloudflare Secret登録
- `EXPO_PUBLIC_AI_API_URL` の設定
- AI作問の実通信試験
- 写真からのOCR。初期TestFlightでは非対象候補
- 正式なアプリアイコンと起動画面
- iPhone実機での主要操作確認
- ClaudeによるUI・動作QA
- P0・P1を0件にする修正
- 人間によるリリース候補承認
- EAS projectId設定
- EAS production buildとSubmit

## 機能凍結条件

次の条件をすべて満たしたコミットをリリース候補として固定する。

1. `npm run check` が成功
2. Workerの構文検査が成功
3. ClaudeのP0・P1が0件
4. iPhone実機で主要導線が完了
5. ユーザーが明示的に承認

現時点では機能凍結前であり、Codexへの申請引き渡し前である。
