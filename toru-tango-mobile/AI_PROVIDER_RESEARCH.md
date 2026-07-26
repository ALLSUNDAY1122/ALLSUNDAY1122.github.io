# 撮る単語帳 AI API選定

更新日: 2026-07-26

## 結論

初回リリースは OpenAI `gpt-5-mini` を採用候補とする。

最安モデルをそのまま採用せず、作問品質を優先する。固定教材20件で `gpt-5-nano` と `gpt-5-mini` を比較し、重複率・誤答率・編集不要率が同等の場合だけ `gpt-5-nano` へ切り替える。

Gemini Developer APIは安価だが、2026-03-23発効の追加規約で、18歳未満を対象または利用が見込まれるAPIクライアントへの使用を禁止している。学生向け単語帳アプリとの適合性に問題があるため、現段階では採用しない。

## 公式料金

100万トークンあたりの標準料金。

| 候補 | 入力 | 出力 | 判断 |
|---|---:|---:|---|
| OpenAI GPT-5 nano | $0.05 | $0.40 | 最安。品質検証が必要 |
| OpenAI GPT-5 mini | $0.25 | $2.00 | 初期品質優先候補 |
| Google Gemini 2.5 Flash-Lite | $0.10 | $0.40 | 安価だが年齢規約が不適合 |
| Google Gemini 2.5 Flash | $0.30 | $2.50 | 本用途には割高 |

想定1回を入力2,000トークン、出力800トークンとした場合の概算:

- GPT-5 nano: 1,000回で約 $0.42
- GPT-5 mini: 1,000回で約 $2.10
- Gemini 2.5 Flash-Lite: 1,000回で約 $0.52
- Gemini 2.5 Flash: 1,000回で約 $2.60

実際の金額は教材の長さ、出題数、モデルの出力トークン量で変動する。

## 品質評価基準

同じ20教材を各モデルへ送り、次を測る。

1. 本文にない事実を追加した割合
2. 同じ事実を一問一答と穴埋めで重複させた割合
3. 答えが問題文に残っている割合
4. 15秒以内で答えられない問題の割合
5. 人が修正せず保存できる問題の割合
6. 10問生成時の平均費用と応答時間

採用条件:

- 重大な事実誤り 0件
- 意味重複率 5%以下
- 編集不要率 90%以上
- JSON Schema違反 0件

## 運用方針

- APIキーをアプリやHTMLへ埋め込まない
- Cloudflare Worker経由で呼び出す
- 1回の本文長と出題数を制限する
- IPまたは匿名端末単位の回数制限を設ける
- 無料ユーザーのAI生成回数に上限を設ける
- API障害時は自動的に簡易作問へ切り替えず、利用者へ明示する
- 端末内簡易作問は別ボタンとして残す

## 公式資料

- OpenAI GPT-5 nano: https://developers.openai.com/api/docs/models/gpt-5-nano
- OpenAI GPT-5 mini: https://developers.openai.com/api/docs/models/gpt-5-mini
- OpenAI APIデータ利用: https://openai.com/enterprise-privacy/
- OpenAI Services Agreement: https://openai.com/policies/services-agreement/
- Gemini API料金: https://ai.google.dev/gemini-api/docs/pricing
- Gemini API追加規約: https://ai.google.dev/gemini-api/terms
- Gemini structured outputs: https://ai.google.dev/gemini-api/docs/structured-output
