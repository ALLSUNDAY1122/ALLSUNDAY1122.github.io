# 撮る単語帳 AI API選定

> **2026-07-29 方針変更**：ユーザー指示により、当面はGemini API無料枠の`gemini-3.5-flash-lite`を採用する。現行判断と評価条件は`AI_GEMINI_BENCHMARK.md`を正本とし、以降のOpenAI比較は旧調査記録として保持する。

更新日: 2026-07-26

## 現在の結論

初回の実通信試験は OpenAI `gpt-5-nano` を使用する。

理由は、標準料金が入力100万トークンあたり $0.05、出力100万トークンあたり $0.40で、候補の中で最も安いこと。Responses APIとStructured Outputsに対応し、作問結果をJSON Schemaで固定できるためである。

Workerの標準設定は次のとおり。

- モデル: `gpt-5-nano`
- reasoning effort: `medium`
- AI失敗時のminiへの自動切替: なし
- AI失敗時の端末内作問への自動切替: なし

nanoの品質が採用条件を満たさない場合に限り、同じ教材と同じ評価条件で `gpt-5-mini` を比較する。モデル変更はCloudflare Workerの環境変数だけで行い、アプリへAPIキーやモデル切替権限を持たせない。

## 公式料金

100万トークンあたりの標準料金。

| 候補 | 入力 | 出力 | 現在の判断 |
|---|---:|---:|---|
| OpenAI GPT-5 nano | $0.05 | $0.40 | 初回試験に採用 |
| OpenAI GPT-5 mini | $0.25 | $2.00 | nano不足時の比較候補 |
| Google Gemini 2.5 Flash-Lite | $0.10 | $0.40 | 年齢規約上の懸念により不採用 |
| Google Gemini 2.5 Flash | $0.30 | $2.50 | 本用途には割高 |

想定1回を入力2,000トークン、出力800トークンとした場合の概算:

- GPT-5 nano: 1,000回で約 $0.42
- GPT-5 mini: 1,000回で約 $2.10
- Gemini 2.5 Flash-Lite: 1,000回で約 $0.52
- Gemini 2.5 Flash: 1,000回で約 $2.60

実際の金額は教材の長さ、推論トークン、出題数、出力長で変動する。Workerは実際の入力・出力・合計トークン数と応答時間をクライアントへ返し、試験時に記録する。

## nano品質評価

同じ20教材をnanoへ送り、次を測る。

1. 本文にない事実を追加した割合
2. 同じ事実を一問一答と穴埋めで重複させた割合
3. 答えが問題文に残っている割合
4. 15秒以内で答えられない問題の割合
5. 人が修正せず保存できる問題の割合
6. 生成前の生カード数とサーバー除外後の採用数
7. 1回あたりの入力・出力トークン、応答時間、概算費用

採用条件:

- 重大な事実誤り 0件
- 意味重複率 5%以下
- 編集不要率 90%以上
- JSON Schema違反 0件
- 20教材中18教材以上で、学習に使えるカードを1枚以上生成

次のいずれかに該当した場合、mini比較へ進む。

- 重大な事実誤りが1件以上
- 意味重複率が5%を超える
- 編集不要率が90%未満
- 不完全な語句や答えが残った問題が繰り返し発生
- 主要教材で必要な事実関係を抽出できない

## 運用方針

- APIキーをアプリやHTMLへ埋め込まない
- Cloudflare Worker経由で呼び出す
- 1回の本文長と出題数を制限する
- IPまたは匿名端末単位の回数制限を設ける
- 無料ユーザーのAI生成回数に上限を設ける
- API障害時は自動的に別モデルや簡易作問へ切り替えず、利用者へ明示する
- 端末内簡易作問は別ボタンとして残す
- 使用モデル、reasoning effort、トークン数、応答時間、除外件数を試験画面へ表示する

## 公式資料

- OpenAI GPT-5 nano: https://developers.openai.com/api/docs/models/gpt-5-nano
- OpenAI GPT-5 mini: https://developers.openai.com/api/docs/models/gpt-5-mini
- OpenAI APIデータ利用: https://openai.com/enterprise-privacy/
- OpenAI Services Agreement: https://openai.com/policies/services-agreement/
- Gemini API料金: https://ai.google.dev/gemini-api/docs/pricing
- Gemini API追加規約: https://ai.google.dev/gemini-api/terms
- Gemini structured outputs: https://ai.google.dev/gemini-api/docs/structured-output
