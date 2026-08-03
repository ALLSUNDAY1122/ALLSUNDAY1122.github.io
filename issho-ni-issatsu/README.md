# いっしょに一冊 — Web試作版（30冊）

Stage 5 で作成したSafari試作（3冊版）を土台に、収録30冊すべてに対応させ、
「やわらかい・暖かい・優しい・楽しい・明るい」を意識してデザインを刷新したブラウザ版です。
価値検証・見せ方確認のためのものであり、公開用の製品ではありません。

## 開き方

`index.html` と `books-data.js` を同じフォルダに置いたまま、`index.html` をSafariやChromeで開きます。
サーバーは不要です（file:// で開けます）。

## できること

- 30冊の絵本だなをカード表示（年齢・テーマでしぼりこみ、フリーワード検索）
- 1冊をタップすると全画面リーダーが開く
- ページ送り（ボタン・スワイプ・キーボード矢印キー）
- 場面ごとの「といかけ」を表示・非表示
- 文字サイズを3段階（小・中・大）で切り替え（設定はブラウザに保存）
- 読み終わると、その本の「おしまいのメッセージ」を表示

## 使っていないもの

- 外部通信・API呼び出し
- 広告・ログイン・アカウント登録
- 追跡・アクセス解析
- 共有・書き出し・SNS連携
- 自動再生・無限スクロール・次の作品の自動推薦

すべての機能はこの2ファイル（`index.html` / `books-data.js`）だけで完結します。
`books-data.js` は `IsshoNiIssatsu/Resources/books.json` と同じ内容を保持しています。

## 実装メモ

- イラストは、ネイティブアプリの `ArtworkView.swift` と同じ考え方（`accent`/`bg` のグラデーション＋絵文字1つ）を
  HTML/CSSで再現しています。将来、自作イラストへ差し替える際は `EMOJI` マップ（`index.html` 内）を
  画像パスへ置き換えるだけで対応できる構造にしています。
- `books.json` を更新した場合は、以下で `books-data.js` を再生成してください。

```bash
python3 -c "
import json
data = json.load(open('../IsshoNiIssatsu/Resources/books.json', encoding='utf-8'))
js = '// 自動生成: IsshoNiIssatsu/Resources/books.json と同一データ\n'
js += 'const BOOKS_DATA = ' + json.dumps(data, ensure_ascii=False, indent=2) + ';\n'
open('books-data.js', 'w', encoding='utf-8').write(js)
"
```

## 既知の制約

- ブラウザのデータ削除で、文字サイズなどの保存設定が消える場合があります（絵本データ自体はファイルに含まれるため消えません）。
- iPhone実機でのスワイプ操作・文字サイズの見え方は、実機での確認を推奨します。
