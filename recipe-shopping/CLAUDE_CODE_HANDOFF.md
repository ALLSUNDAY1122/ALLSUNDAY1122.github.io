# Claude Code 引継ぎ｜まとめ買いレシピ API実装版

更新日時: 2026-08-02 13:01 JST

## 1. プロジェクト概要

レシピ画面のスクリーンショットから材料名・数量・単位・人数を抽出し、複数レシピの材料を統合して買い物リストを作成するWebアプリ。

中心価値:
- スクリーンショットから材料を保存できる
- 複数レシピの同一材料を合算できる
- 常備品を除外できる
- スーパーで使えるチェックリストにできる

競合「キープレシピ」を実際に試したところ、スクリーンショットから保存できないケースがあったため、開発を継続する。

## 2. 正本と公開URL

- GitHubリポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- 公開ディレクトリ: `recipe-shopping/`
- 従来OCR版: `recipe-shopping/index.html`
- Gemini API試験版: `recipe-shopping/api.html`
- 公開URL: https://allsunday1122.github.io/recipe-shopping/api.html
- Cloudflare Workerコード: `recipe-shopping-api/worker.js`
- Worker設定: `recipe-shopping-api/wrangler.jsonc`

## 3. 現在の構成

### フロントエンド

GitHub Pages上の単一HTML構成。

`api.html`では以下を実装済み。
- iPhoneから画像選択
- 画像プレビュー
- Gemini APIによる画像解析
- JSON形式の材料抽出
- 材料名・数量・単位の編集
- レシピの端末内保存
- 複数レシピ選択
- 人数変更
- 同一材料の統合
- 常備品除外
- 買い物チェックリスト

### API

2方式を想定。

1. 開発検証用
   - 利用者がGemini APIキーをブラウザへ入力
   - APIキーはGitHubソースには保存しない
   - ブラウザ保存のみ

2. 公開運用用
   - GitHub Pages → Cloudflare Worker → Gemini API
   - Gemini APIキーはCloudflare Secretとして保持
   - ブラウザへキーを公開しない

## 4. AI抽出要件

画像から次をJSONで返す。

```json
{
  "recipeName": "料理名",
  "servings": 2,
  "ingredients": [
    {
      "name": "玉ねぎ",
      "quantity": 0.5,
      "unit": "個",
      "note": "100g",
      "confidence": 0.95
    }
  ],
  "warnings": []
}
```

抽出ルール:
- ステータスバーの時刻、電池残量、通信表示を除外
- 広告、アプリ誘導、見出し、作り方を除外
- 材料名を省略しない
- `1/2個(100g)`は quantity=0.5、unit=個、note=100g
- `小さじ1/2`は quantity=0.5、unit=小さじ
- `3かけ(60g)`は quantity=3、unit=かけ、note=60g
- 主表示単位を優先し、括弧内重量は補足にする
- 判読不能な内容を推測で確定しない
- 信頼度が低い材料はwarningsへ入れる

## 5. 既知の問題

### 従来OCR版

Tesseract.jsでは日本語の材料欄に対して精度不足。

実例:
- ごはん → ご
- 豚こま切れ肉 → 豚
- 1/2個(100g) → 172100
- 時刻6:03を材料として認識

従来OCRを主処理に戻さないこと。必要ならオフライン時の予備機能に限定する。

### API版

- Gemini APIキー未設定のため、実際のAPI応答を通した実機検証は未完了
- Cloudflare Worker未配備
- Worker URL未確定
- APIの無料枠超過、429、タイムアウト処理の実機確認が必要
- GitHub PagesのCORSとWorkerの許可Originを確認する必要がある
- AIが返すJSONのスキーマ検証をさらに厳格化する必要がある

## 6. Claude Codeに最初に実施してほしいこと

1. リポジトリ全体を確認する
2. `recipe-shopping/api.html`を起点に構造を整理する
3. `recipe-shopping-api/worker.js`と`wrangler.jsonc`を監査する
4. Geminiの現行公式API仕様に合わせてモデル名・エンドポイント・構造化出力方式を確認する
5. APIキー直入力方式がGitHubソースへ露出しないことを確認する
6. Worker方式を主経路、直接APIキー方式を開発者モードにする
7. JSONスキーマ検証と異常値検出を実装する
8. 画像サイズ圧縮、EXIF回転、HEIC/JPEG/PNG対応を確認する
9. iPhone Safariで主要操作が止まらないようにする
10. READMEにCloudflare配備手順を完成させる

## 7. 必須テスト画像

DELISH KITCHENの材料画面スクリーンショットを基準画像とする。

期待値:

| 材料 | 数量 | 単位 | 補足 |
|---|---:|---|---|
| ごはん | 2 | 杯 | 300g |
| 豚こま切れ肉 | 150 | g | |
| 玉ねぎ | 0.5 | 個 | 100g |
| にんじん | 0.5 | 本 | 75g |
| じゃがいも | 1 | 個 | 150g |
| おろしにんにく | 0.5 | 小さじ | |
| サラダ油 | 2 | 小さじ | |
| 水 | 400 | cc | |
| ウスターソース | 1 | 大さじ | |
| ケチャップ | 1 | 大さじ | |
| カレールウ | 3 | かけ | 60g |

合格基準:
- ステータスバーや広告を材料に含めない
- 材料名を途中で切らない
- 分数を正しく数値化する
- 括弧内重量と主単位を混ぜない
- 11項目中10項目以上を修正なしで抽出
- 誤認識箇所は保存前に明確に警告する

## 8. セキュリティ要件

- Gemini APIキーをHTML、JavaScript、Git履歴へ書かない
- CloudflareではSecretを使用する
- Workerは許可OriginをGitHub PagesのURLに限定する
- リクエストサイズ上限を設ける
- 画像を永続保存しない
- ログへ画像本体やAPIキーを出さない
- レート制限を実装する
- エラー本文に機密情報を含めない

## 9. 次の成果物

Claude Codeで次を完成させる。

- Cloudflare Worker配備可能な実装
- `.dev.vars.example`
- 配備手順README
- フロントエンドのWorker URL設定方法
- Geminiレスポンスのスキーマ検証
- APIエラー表示
- 画像圧縮
- テストケース
- 基準画像での抽出結果記録
- GitHub Pagesの更新

## 10. 開発方針

- UIの大幅変更より、まず抽出精度と保存成功率を優先する
- AI抽出結果は必ず利用者が確認してから保存する
- 既存レシピサイトの本文・手順は保存せず、料理名・材料・分量・元情報など必要最小限にする
- 自動抽出が失敗しても手入力で完了できるようにする
- 仕様変更、API選定変更、課金導入はユーザー確認を取る
