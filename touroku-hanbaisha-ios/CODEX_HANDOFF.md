# 登録販売者｜学びスプリント Codex引継ぎ

## 正本
- Notion「登録販売者｜学びスプリント 開発正本」
- Notion「申請手順」
- Notion「【正本】対象アプリ識別情報｜App Store Connect / Codemagic」
- GitHub `touroku-hanbaisha-sprint/`（Safari版・canonical 360問）
- GitHub `touroku-hanbaisha-ios/`（iOSラッパー）

会話履歴ではなく、作業開始時にNotion/GitHubの最新実状態を再取得すること。

## 現在の確定値
- App name: `登録販売者｜学びスプリント`
- Apple Team ID: `MN3D2ZM44N`
- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect Apple ID: `6802119268`
- SKU: `tourokuhanbaisha-manabi-sprint`
- Version: `1.0.0`
- Codemagic profile: `tourokuhanbaisha_appstore`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査への自動提出は禁止

## 完了済み
- canonical問題 3回×120問＝360問
- 各回5分野 20/20/40/20/20
- 全360問の正答・解説・重複・高類似・水増し・現行法令監査 PASS
- canonical CI PASS
- Safari実機確認 PASS
  - 15分類
  - 回答→解説
  - 途中再開
  - 第1〜3回120問通し
  - 履歴カレンダー
  - 当日履歴即時更新
- App Store Connect Appレコード作成済み

## 重要な直近修正
- App Store metadataの旧「120問」表記は全360問へ更新済み。
- 履歴カレンダーはSafari実機確認中に追加・修正済み。

## 次工程
申請手順に従い、本人確認が必要な地点まで自律的に進める。

1. 最新のNotion/GitHub状態を再取得
2. `touroku-hanbaisha-ios/` の申請前監査
3. AppIcon正本をGoogle Drive `AppIcon_採用版_2026-08-09` から資格名一致PNGで特定。見つからない場合は勝手に代用品を使わず、正本ルールに従う
4. Privacy / Support URL / App Store metadata / Review Notesを実装と再照合
5. Expo/React Nativeラッパーの静的検査、依存関係、Expo Doctor等を実行
6. TestFlight配布経路を決定。標準手順の無料枠優先ルールに従い、Codemagic/EASを比較する
7. Bundle ID、Apple ID、Team ID、Versionを固定して署名設定
8. signed IPA → Internal TestFlight uploadまで可能な限り進める
9. Appleログイン、2FA、秘密鍵など本人操作が必要な場合だけ停止し、必要な操作を1画面単位で明示する

## 禁止事項
- Bundle IDを変更しない
- App Store Connect Apple IDを推測・変更しない
- パスワード、2FAコード、API秘密鍵をGitHub/Notionへ保存しない
- Internal TestFlight確認前にApp Store本審査へ提出しない
- Safari版360問の問題内容を理由なく再編集しない
- 完了済み監査を無意味にやり直さない

## 目標
人間確認が本当に必要になる直前まで停止せず進め、最終的にInternal TestFlightへ配布する。
