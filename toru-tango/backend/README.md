# 撮る単語帳 AIバックエンド

Cloudflare Workers上で動作し、Gemini APIキーをアプリやGitHubへ公開せずに教材文から問題を生成します。

## 構成

- `src/index.js`: `/generate` API本体
- `tests/worker.test.js`: 正常系・異常系テスト
- `wrangler.jsonc`: Cloudflare Workers設定
- `package.json`: 開発・検査・公開コマンド

## AIモデル

- Provider: Google Gemini Developer API
- Model: `gemini-3.5-flash-lite`
- 出力: JSON Schemaによる構造化出力

Gemini APIの無料枠を当面使用します。無料枠にはレート制限があり、利用条件は変更される可能性があります。また、Googleの料金表では無料枠の入力・出力が製品改善に使われる旨が示されています。公開前にプライバシーポリシーとApp Store回答を再確認してください。

## 初回公開

1. [Google AI Studio](https://aistudio.google.com/apikey)でGemini APIキーを作成する。
2. Cloudflareへログインする。
3. このディレクトリで `npm install` を実行する。
4. `npx wrangler login` を実行する。
5. `npx wrangler secret put GEMINI_API_KEY` を実行し、Gemini APIキーを入力する。
6. `npm test` を実行する。
7. `npm run deploy` を実行する。
8. 表示された `https://toru-tango-ai.<subdomain>.workers.dev` を控える。

APIキーはCloudflare Secretへ保存し、GitHubやアプリへコミットしないでください。

GitHub Actionsから公開する場合は、Repository secretsへ次を設定します。

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `TORU_TANGO_GEMINI_API_KEY`

## API

`POST /generate`

```json
{
  "source": "教材本文",
  "count": 10,
  "type": "mix",
  "difficulty": "normal"
}
```

成功例:

```json
{
  "questions": [
    {
      "question": "日本国憲法が施行された日は？",
      "answer": "1947年5月3日",
      "type": "qa"
    }
  ],
  "provider": "Google Gemini",
  "model": "gemini-3.5-flash-lite"
}
```

## セキュリティ

- CORSは `https://allsunday1122.github.io` のみに制限。
- Gemini APIキーはCloudflare Secretで管理。
- 教材本文は最大12,000文字、作問数は最大20問。
- レスポンスはキャッシュしない。
- APIキーや教材本文をログへ出力しない。
- AI失敗時に別モデルや端末内作問へ自動切替しない。

## フロント接続

Worker公開後、アプリ側のAPI URLを次の形式に設定します。

```text
https://toru-tango-ai.<subdomain>.workers.dev/generate
```

端末内簡易作問は別ボタンとして維持します。
