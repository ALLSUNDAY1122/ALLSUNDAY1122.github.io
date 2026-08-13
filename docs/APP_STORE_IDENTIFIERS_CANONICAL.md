# 【正本ミラー】対象アプリ識別情報｜App Store Connect / Codemagic

更新: 2026-08-13

このファイルは、Notion正本「【正本】対象アプリ識別情報｜App Store Connect / Codemagic」のGitHubミラーです。
識別情報はユーザー指定値を最上位正本として扱い、外部検索、過去チャット、既存コード、命名規則、推測で変更・補完しません。ユーザーが命名判断を明示的にAIへ委任した場合は、その委任範囲に限りAIが値を決定して正本へ記録できます。Appleが自動発行する数値IDは実発行値だけを記録します。

Notion正本:
https://app.notion.com/p/3b709c10697d8138a352c422d4dd5c47

## 共通設定

- Apple Team ID: `MN3D2ZM44N`
- iOS Version: `1.0.0`
- Distribution: `App Store`
- TestFlight: `Internal Testing only`
- App Store本審査への自動提出は禁止
- Bundle ID、App Store Connect App ID、資格名を勝手に変更しない
- App Store Connect App IDが未記載のものは推測せずBundle IDを基準に実装する
- Codemagic署名設定は各アプリに指定されたprofile名を使用する

## 対象アプリ

| # | アプリ | Bundle ID | App Store Connect App ID | Codemagic profile | IAP |
|---|---|---|---|---|---|
| 1 | 危険物乙4｜学びスプリント | `jp.allsunday1122.otsu4` | `6799755566` | `otsu4_appstore` | `jp.allsunday1122.otsu4.premium` |
| 2 | 通関士｜学びスプリント | `jp.allsunday1122.tsukanshi` | `6799753744` | `tsukanshi_appstore` | 未記載 |
| 4 | 管理栄養士国家試験｜学びスプリント | `jp.allsunday1122.kanrieiyoushi` | `6799753841` | `kanrieiyoushi_appstore` | 未記載 |
| 5 | 薬剤師国家試験｜学びスプリント | `jp.allsunday1122.yakuzaishi` | `6799753724` | `yakuzaishi_appstore` | 未記載 |
| 6 | 応用情報技術者試験｜学びスプリント | `jp.allsunday1122.apmanabisprint` | 未記載・推測禁止 | `apmanabisprint_appstore` | 未記載 |
| 7 | ネットワークスペシャリスト試験｜学びスプリント | `jp.allsunday1122.networkspecialist` | 未記載・推測禁止 | `networkspecialist_appstore` | 未記載 |
| 9 | 公認会計士短答｜学びスプリント | `jp.allsunday1122.cpamanabisprint` | `6799754783` | `cpamanabisprint_appstore` | 未記載 |
| 10 | 司法書士｜学びスプリント | `jp.allsunday1122.shoshi` | `6799755748` | `shoshi_appstore` | `jp.allsunday1122.shoshi.premium` |
| 13 | 保健師国家試験｜学びスプリント | `jp.allsunday1122.hokenshi` | Apple発行待ち・推測禁止 | `hokenshi_appstore` | `jp.allsunday1122.hokenshi.premium` |

## 運用ルール

1. 実装・署名・Codemagic・App Store Connect入力前にこの正本を確認する。
2. 他資料と不一致なら、この正本を優先して他資料を修正する。
3. 未記載値を外部検索や命名規則から作らない。
4. 新しいApp Store Connect App IDやIAPは、ユーザーが値を明示するか、命名判断を明示的にAIへ委任した場合に限り追記する。Appleが自動発行する数値IDは実発行値だけを記録する。
5. TestFlightはInternal Testing only。本審査の自動提出は禁止する。
