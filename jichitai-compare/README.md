# 自治体くらべ

日本地図から自治体を選び、子育て・住宅・公共サービスを比較する静的サイトです。

公開URL: https://allsunday1122.github.io/jichitai-compare/

## 現在の機能

- クリックできる日本地図（外部SVGの読み込み失敗時は都道府県一覧に切替）
- 自治体名検索
- 最大3自治体の比較
- 子どもの年齢による簡易対象判定
- 比較条件を保存した共有URL
- 自治体公式サイトと制度出典へのリンク
- 江戸川区・市川市・浦安市の確認済みデータ
- 9制度の共通データ形式
- 自治体別データ・進捗・生成物の検証
- GitHub Actionsによる公開サイトのスモークテスト

## 技術構成

- HTML / CSS / Vanilla JavaScript
- 静的JSON
- GitHub Pages
- Node.js 20による生成・検証
- サーバー、データベース、APIキー不要

## データ構成

- `data/service-definitions.json`: 制度名、表示順、判定方法、表示する詳細項目
- `data/municipalities/{prefectureCode}/{municipalityCode}.json`: 自治体ごとの元データ
- `operations/tasks/{municipalityCode}.json`: 担当班、現在の制度、件数、ブランチ、PR、停滞理由
- `data/generated/municipalities.json`: 公開画面が読む生成済みJSON
- `operations/progress.json`: 全国・地方班・自治体別の生成済み進捗
- `operations/PARALLEL_READY`: 4地方調査班の作業開始条件

旧一括ファイル `data/municipalities.json` は、Phase 0の移行・公開確認完了後に廃止しました。移行元の内容とblob SHAは `operations/migration-manifest.json` とGit履歴に残しています。

## status

自治体・進捗では次のstatusを使用できます。

- `todo`: 未着手
- `researching`: 調査中
- `verified`: 公式情報で確認済み
- `unavailable`: 制度なし・対象外を確認済み
- `needs_medium_review`: 詳細判断が必要
- `needs_revision`: 修正が必要
- `needs_coordinator`: 全国統括の対応が必要
- `pr_open`: PR審査中
- `merged`: main統合済み
- `blocked`: 作業停止中

制度単位では通常、`todo`、`researching`、`verified`、`unavailable`、`needs_medium_review`、`needs_revision`、`needs_coordinator`、`blocked`を使用します。

`verified`または`unavailable`の制度には、公式HTTPS URLの`source.url`と、`YYYY-MM-DD`形式の`source.checkedAt`が必要です。

## 自治体の追加・更新

1. 自治体コードに対応する `data/municipalities/{prefectureCode}/{municipalityCode}.json` を作成または更新
2. `service-definitions.json`にある9制度をすべて`services`へ登録
3. 対応する `operations/tasks/{municipalityCode}.json` を作成または更新
4. 不明項目は推測せず、`todo`または`researching`とする
5. 次を実行

```bash
npm run check
node --check app.js
```

`npm run check`は、元データ検証、公開JSON生成、全国進捗生成、生成データ再検証を実行します。

## 並列運用

担当区域は次のとおりです。

- 北日本調査班: 都道府県コード01〜07
- 東日本調査班: 08〜15、19、20
- 中日本調査班: 16〜18、21〜30
- 西日本調査班: 31〜47

2026年7月22日以降、各地方はA/Bの2セッション、合計8セッションで運用します。詳細な担当都道府県コードと分割時点の未調査数は`operations/session-split-policy.json`を正式基準とします。従来の4セッションはAとして継続します。

地方統合ブランチは4本のまま共有します。A/Bは自治体単位の専用ブランチとPRで、割り当てられた自治体元データ、task、自分専用のsession checkpointだけを編集します。`data/generated/municipalities.json`、`operations/progress.json`、共有の地域・全国状態、共通スクリプト、共通画面ファイルは編集長・全国統括が管理します。

## データ方針

- 原則として自治体公式ページを出典とする
- 各確認済み制度に確認日を付ける
- 不明な項目は推測しない
- 判定結果は参考情報であり、正式な対象可否は自治体へ確認する
- 自治体単位でレビュー可能な更新に分ける
- 生成済みJSONを手編集せず、元データから再生成する

## 次の開発順序

1. 江戸川区・市川市・浦安市の未調査制度を追加
2. 東京23区・千葉県北西部へ自治体を拡張
3. 北日本・中日本・西日本の初期自治体を登録
4. 市区町村境界地図を都道府県単位で追加
5. 世帯年収、子どもの人数、住宅形態の判定ルールを追加
6. 独自ドメイン・広告表示方針を決定

## 地図ライセンス

日本地図はGeolonia `japanese-prefectures`を使用します（GFDL）。
