# クリップボードWidget｜App Store Connect 新規Appレコード作成 packet

このファイルは、Notion「申請手順」の HUMAN-REQUIRED ゲートである新規App Store Connect Appレコード作成にだけ使用する。

## 入力値

- Platforms: iOS
- Name: クリップボードWidget
- Primary Language: Japanese (日本語)
- Bundle ID: jp.allsunday1122.clipboardwidget
- SKU: clipboard-widget-20260827
- User Access: Full Access

## 作成後

数値App Store Connect App IDを人間が転記しない。
次回の自動runでBundle ID `jp.allsunday1122.clipboardwidget` をAPI検索し、Apple実発行App IDを取得して正本へ反映する。
そのままCodemagic `clipboard-widget-phase0` を起動し、signed IPA → App Store Connect upload → Apple build read-backまで連結する。

## 禁止

- Bundle IDの変更
- SKUの変更
- App Store本審査への提出
- Submit for Review

## 現在の機械状態

- App + Widget Extension compile: PASS
- Distribution certificate / provisioning profiles: prepared
- Signed IPA generation: PASS
- App Store Connect upload: blocked only because App record is absent
- Latest App Store Connect API read-back: Bundle ID match_count = 0
