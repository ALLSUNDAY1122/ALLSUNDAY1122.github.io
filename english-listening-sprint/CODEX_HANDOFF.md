# English Listening Sprint — release handoff

更新日: 2026-11-28

## 目標

TestFlight内部テストまで。App Store本審査提出は対象外。

## 正本

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Release branch: `codex/english-listening-testflight-v2`
- Product path: `english-listening-sprint/`
- Codemagic app: `ALLSUNDAY1122.github.io`
- Workflow: `english-listening-sprint-testflight`

## 識別子

- App name: `English Listening Sprint`
- Bundle ID: `jp.allsunday1122.englishlistening`
- Team ID: `MN3D2ZM44N`
- Version / Build: `1.0.0 (1)`
- SKU: `ENGLISH-LISTENING-SPRINT-IOS-001`
- App Store Connect App ID: `6840230101`
- App Store provisioning profile: `English Listening Sprint App Store`（Active、2027-08-19まで）

## 実装とプライバシー

SwiftUIネイティブ実装。30レッスン、90設問、312本のMP3を同梱する。完了レッスンIDをUserDefaultsへ保存する以外のデータ保存・送信はない。広告、分析、ログイン、課金、外部教材取得はない。

## 再開地点

1. App Store Connect App ID `6840230101` と配信用プロファイル `English Listening Sprint App Store` の状態を確認済み。
2. Codemagicで`english-listening-sprint-testflight`を `codex/english-listening-testflight-v2` から実行する。
3. 署名済みIPA・監査結果・App Store Connect処理結果を確認する。
4. TestFlight内部テストへの到達を確認し、依頼者に実機確認を依頼する。

秘密情報と本人情報は記録しない。外部TestFlightとApp Store本審査へは自動で進めない。
