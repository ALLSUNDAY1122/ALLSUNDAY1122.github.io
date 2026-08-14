# Splat Lab Native｜Release Status

更新日: 2026-08-15

## 現在地

`MACHINE GREEN → APP STORE CONNECT RECORD WAITING`

機械側で実行できる開発・監査はInternal TestFlight直前まで完了しています。

## PASS済み

- ARKit撮影・camera-to-world pose取得
- rawFeaturePoints収集・初期PLY生成
- Nerfstudio transforms.json生成
- msplat Metal学習経路
- result.splat書出し
- MetalSplatter表示
- .splat 32-byte layout / quaternion互換監査
- 初回撮影開始ライフサイクル修正
- ARSession失敗・中断復旧
- Swift 6 / iPhone Release compile
- Privacy Manifest
- 外部送信・解析SDKなし監査
- 1024px AppIcon生成経路
- 第三者ライセンス同梱
- App Store metadata draft
- Review notes
- Privacy page / Support page
- Internal TestFlight実機テスト手順
- TestFlight専用Codemagic workflow
- App Store本審査自動提出禁止

## GitHub

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Source branch: `feature/splat-native-ios-poc`
- TestFlight branch: `testflight/splat-native-ios`
- Main draft PR: #4145
- TestFlight sync PR: #4147（手動2-parent mergeで内容同期済み。整理対象）

## Apple識別子

- Bundle ID: `jp.allsunday1122.splatlab`
- Version: `1.0.0`
- App Store Connect Apple ID: 未発行。推測禁止。

## 次の不可避な人間操作

App Store Connect Web UIで新規Appレコードを作成する。

入力値は `APPLE_CONNECT_PACKET.md` を正本とする。

Apple IDが発行されたら、機械側で正本反映→Codemagic signed IPA→Internal TestFlight uploadの監査へ戻る。

## その次の人間判断

Internal TestFlight実機で3D品質・生成時間・熱・メモリを確認し、PASS / CONDITIONAL / FAILを判断する。
