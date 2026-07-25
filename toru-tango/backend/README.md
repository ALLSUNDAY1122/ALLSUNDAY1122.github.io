# 撮る単語帳 AIバックエンド

Cloudflare Workers上で動作し、OpenAI APIキーをブラウザやGitHubへ公開せずに教材文から問題を生成します。

## 構成

- `src/index.js`: `/generate` API本体
- `wrangler.jsonc`: Cloudflare Workers設定
- `package.json`: 開発・公開コマンド

## 初回公開

1. Cloudflareへログインする。
2. このディレクトリで `npm install` を実行する。
3. `npx wrangler login` を実行する。
4. `npx wrangler secret put OPENAI_API_KEY` を実行し、OpenAI APIキーを入力する。
5. `npm run deploy` を実行する。
6. 表示された `https://toru-tango-ai.<subdomain>.workers.dev` を控える。

APIキーはCloudflare Secretへ保存し、GitHubへコミットしないでください。

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
  ]
}
```

## セキュリティ

- CORSは `https://allsunday1122.github.io` のみに制限。
- OpenAI APIキーはCloudflare Secretで管理。
- 教材本文は最大12,000文字、作問数は最大20問。
- レスポンスはキャッシュしない。
- APIキーや教材本文をログへ出力しない。

## フロント接続

Worker公開後、Webアプリ側のAPI URLを次の形式に設定します。

```text
https://toru-tango-ai.<subdomain>.workers.dev/generate
```

公開URLが確定するまでは、現在の端末内作問機能をフォールバックとして維持します。
