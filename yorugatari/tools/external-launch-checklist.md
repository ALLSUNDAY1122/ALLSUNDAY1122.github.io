# 夜語り 外部投稿チェックリスト

更新日：2026年7月24日

## 投稿前

1. `external-launch-status.json` の `nextCampaignId` を確認する。
2. 対応する文面とURLを `external-launch-kit.md` からそのまま使用する。
3. 1日に投稿するのは原則1本だけとする。
4. 計測URLの `utm_source`、`utm_medium`、`utm_campaign`、`utm_content` を変更しない。

## 投稿直後

投稿を実際に公開した場合だけ、`external-launch-status.json` の該当行を次のように変更する。

- `status`: `ready_not_posted` → `published`
- `publishedAt`: 投稿日時をISO 8601形式で記録
- `postUrl`: 公開した投稿のURLを記録
- `nextCampaignId`: 次の優先順位のキャンペーンIDへ変更

投稿していないキャンペーンに日時や投稿URLを記録してはいけない。

## 投稿後24時間

- 原則として削除・再投稿・URL変更を行わない。
- 誤字などで投稿を削除した場合は、台帳を `paused` に変更して理由を別途記録する。
- 流入0件でも、24時間経過前に文面の良否を判断しない。

## 比較開始条件

- 1投稿10流入未満：参考値として継続観測する。
- 1投稿10流入以上：文面と着地ページを再利用候補にする。
- 投稿済みキャンペーン合計30流入以上：媒体別比較を開始する。
- 各特集の基準値後閲覧30件以上：特集から作品を読み始めた割合を比較する。
- 作品閲覧100件かつ7日分の観測前：作品の人気順を変更しない。

## 確認するファイル

- 投稿文と計測URL：`external-launch-kit.md`
- 投稿済み・未投稿の台帳：`external-launch-status.json`
- アクセスと特集開始率の統合結果：`analytics-insights-latest.md`
- 数値の原本：`analytics-snapshot-latest.json`
- 特集開始率の原本：`landing-conversion-latest.json`
