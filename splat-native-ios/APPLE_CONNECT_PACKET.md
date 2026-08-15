# Scan Lab｜Apple Developer / App Store Connect 登録パケット

更新日: 2026-08-15

## 固定値

- App name: `Scan Lab`
- Platform: iOS
- Primary language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- Version: `1.0.0`
- Team ID: `MN3D2ZM44N`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store review auto-submit: disabled

`Bundle ID` は既存技術名の `splatlab` を維持しますが、ユーザーに見えるApp名・ホーム画面表示名・App Store Connect名は `Scan Lab` に統一します。

## Apple Developer側

`testflight/splat-native-ios` ブランチのCodemagic workflowには、Bundle IDが存在しない場合に `jp.allsunday1122.splatlab` のExplicit App IDを作成し、App Store配布用の署名ファイルを取得・生成する処理があります。

したがって、手作業で先にBundle IDを作る必要はありません。Codemagicが権限不足等で失敗した場合のみ、その失敗内容に応じて人間操作へ切り替えます。

ただし、**TestFlight workflowを起動する前に、`testflight/splat-native-ios` をその時点の最新S0統合状態へ同期することが必須**です。S8確認時点（2026-08-15）ではTestFlight枝はS0より遅れて分岐しており、そのままのビルドを品質判定に使ってはいけません。

## App Store Connect側で人間が行う登録

新規Appレコードの作成はWeb UIで人間が行います。

入力値:

- Platforms: iOS
- Name: Scan Lab
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- User Access: Full Access（特別に制限する必要がない場合）

作成後に発行されるApple ID（数値）は推測せず、実値をNotion正本とこのパケットへ記録します。

## Appレコード作成後の自動経路

最新統合状態へ同期済みの `testflight/splat-native-ios` ブランチでCodemagic workflowを実行します。

1. Release入力監査
2. Explicit Bundle ID確認/必要時作成
3. App Store signing files取得/必要時作成
4. signed IPA生成
5. App Store Connectへupload
6. Internal TestFlightへ送信
7. App Store本審査には送信しない

Codemagicの `CM_BUILD_NUMBER` を `CURRENT_PROJECT_VERSION` へ反映してからXcodeGenを実行します。同じbuild番号を再アップロードしないことをrelease gateとします。

## Internal TestFlight後に必要な人間判断

実機でScaniverse同条件の代表スキャンと比較し、次のどれかを判断します。

- PASS: 主要な個人向け機能・品質・操作性が同等化基準を満たす
- CONDITIONAL: 生成可能だが品質・速度・熱・UXに課題があり、改善後の再試験が必要
- FAIL: オンデバイス方式または現在の実装が実用品質に届かず、方式再設計が必要

この判断以前にApp Store本審査へ提出しません。
