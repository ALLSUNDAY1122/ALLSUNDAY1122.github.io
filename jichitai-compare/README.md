# 自治体くらべ MVP

日本地図から自治体を選び、子育て・住宅・公共サービスを比較する静的サイトです。

## 現在の機能

- クリックできる日本地図（外部SVGの読み込み失敗時は都道府県一覧に切替）
- 自治体名検索
- 最大3自治体の比較
- 子どもの年齢による簡易対象判定
- 比較条件を保存した共有URL
- 自治体公式サイトと制度出典へのリンク
- 江戸川区・市川市・浦安市の確認済みデータ
- 9制度に拡張できる共通データ形式
- JSONデータ検証スクリプト

## 技術構成

- HTML / CSS / Vanilla JavaScript
- 静的JSON
- GitHub Pagesで動作
- サーバー、データベース、APIキー不要

ChatGPTまたはCodexがJSONと画面ファイルを更新するだけで、自治体・制度を追加できる構成を優先しています。

## データファイル

- `data/service-definitions.json`: 制度名、表示順、判定方法、表示する詳細項目
- `data/municipalities.json`: 自治体基本情報と自治体ごとの制度内容

制度の状態は次の3種類です。

- `verified`: 自治体公式ページで確認済み
- `researching`: 調査中
- `unavailable`: 制度なし、または対象外であることを確認済み

確認済み制度には、必ず `source.url` と `source.checkedAt` を登録します。年齢判定を行う制度には、`eligibility.minAgeMonths` と `eligibility.maxAgeYears` を登録します。

## 自治体の追加

1. `data/municipalities.json` の `municipalities` 配列へ自治体を追加
2. `service-definitions.json` にある全制度IDを `services` に作成
3. 未調査制度は推測せず `researching` とする
4. 次を実行

```bash
npm run validate
```

## 制度の追加

1. `data/service-definitions.json` に制度定義を追加
2. 全自治体の `services` に同じ制度IDを追加
3. JavaScriptを修正せず、共通表示・判定処理で表示できることを確認
4. `npm run validate` を実行

## データ方針

- 原則として自治体公式ページを出典とする
- 各確認済み制度に確認日を付ける
- 不明な項目は推測しない
- 判定結果は参考情報であり、正式な対象可否は自治体へ確認する
- 自治体単位でレビュー可能な更新に分ける

## 次の開発順序

1. 江戸川区・市川市・浦安市の未調査制度を追加
2. 東京23区・千葉県北西部へ自治体を拡張
3. 市区町村境界地図を都道府県単位で追加
4. 世帯年収、子どもの人数、住宅形態の判定ルールを追加
5. 独自ドメイン・広告表示方針を決定

## 地図ライセンス

日本地図は Geolonia `japanese-prefectures` を使用します（GFDL）。
