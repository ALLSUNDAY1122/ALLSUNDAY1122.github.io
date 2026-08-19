# APP2-007｜危険物乙4｜分野から解くタップ不具合修正

完了判定: **DONE**
確認時点: 2026-08-19 15:10 JST
Worker: OTSU4

## 正本再取得
- Notion台帳「危険物取扱者 乙種4類｜学びスプリント」: 2026-08-18実機報告「分野から解くが押せない」を最優先未解決として記録。
- Notion開発正本: Bundle ID `jp.allsunday1122.otsu4` / App Store Connect App ID `6799755566` / Version `1.0.0` / Codemagic workflow `otsu4-ios` / profile `otsu4_appstore` / IAP `jp.allsunday1122.otsu4.premium` / AppIcon SHA-256 `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d`。
- GitHub PR #4069: Draft / head `cec69cc72f415367031776d255102fba5261b4c5`。

## タップ不具合の現行source判定
現行head `cec69cc72f415367031776d255102fba5261b4c5` には `test(otsu4): cover subject row tap regression` が含まれる。
`native-ios/Otsu4Sprint/UITests/Otsu4SprintUITests.swift` の `testEachSubjectRowIsFullyTappableAndStartsFreeStudyFlow()` で、以下3分野を実ボタンとして検証する。
- 法令
- 物理・化学
- 性質・消火

各行について存在、hittable、44pt以上、左側座標タップ、無料版学習画面の「わからない」到達を検証するため、直近実機報告の再発回帰を直接カバーしている。製品sourceへの追加修正は不要と判定。

## Release Gate
現行headに紐づくGitHub Actions:
- Otsu4 Content Audit run `32115827629`: success
- Otsu4 Native Typecheck run `32115827647`: success
- Otsu4 Xcode Build run `32115827620`: success
- Otsu4 Release Foundation Lint run `32115827669`: success

Xcode Build run `32115827620` の主要step:
- Release Simulator Build: success
- release bundle / canonical identifiers: success
- small / large iPhone simulator selection + boot: success
- native unit tests: success
- small / large iPhone UI tests: success
- canonical App Store icon SHA: success

## 新署名Build
旧ASC Build 1は2026-08-10アップロードで、2026-08-18実機報告より前のため受入証拠として失効扱い。

修正版sourceを固定した release branch `release/app2-007-otsu4-testflight` から、Codemagic artifact-only Buildを生成。
- Codemagic Build ID: `6a852847e0a1ce2d5417944d`
- Codemagic status: `finished`
- product source head: `cec69cc72f415367031776d255102fba5261b4c5`
- exact IPA size: 1,960,985 bytes
- actual Bundle ID: `jp.allsunday1122.otsu4`
- actual Version: `1.0.0`
- actual CFBundleVersion: `2`
- codesign: verified

途中で判明したBuild番号問題は、Xcode project内のBuild番号定義が複数箇所にあり旧IPAがBuild 1のままになることが原因だった。最終artifactでは実IPAを展開してBuild 2をread-back済み。

## App Store Connect / Internal TestFlight read-back
App Store Connect `/v1/apps/6799755566/builds?limit=10` read-back:
- Build 2 resource ID: `d88cc444-e53c-4a8b-873a-1a0975d87fa3`
- version: `2`
- processingState: `VALID`
- buildAudienceType: `INTERNAL_ONLY`
- uploadedDate: `2026-08-18T20:54:52-07:00`
- expired: false

Internal TestFlight group `sun` (`9cd34e64-9d08-4203-a27d-cb9d2e661c96`) read-back:
- Build 2 `d88cc444-e53c-4a8b-873a-1a0975d87fa3` が所属済み
- processingState `VALID`
- buildAudienceType `INTERNAL_ONLY`
- 旧Build 1とBuild 2の2件を確認

`altool --validate-app` でBuild 2再送を試した際、Appleは `previousBundleVersion: 2` / duplicate を返した。この結果と上記ASC read-backにより、Build 2が既にAppleへ正常到達済みであることを確認したため追加uploadは行わない。

## 安全条件
- App Store本審査への提出: **未実施**
- `submit_to_app_store: true`: **使用していない**
- PR #4069: Draft維持
- Bundle ID / App ID / IAP / profile: 変更なし
- secret / token / .p8: 証拠へ保存していない

## 結論
直近実機報告「分野から解くが押せない」は、現行sourceの専用UI回帰テストと小型・大型iPhone Release Gateで解消済みと判定。さらに修正版sourceから新署名IPA `1.0.0 (2)` を生成し、App Store Connectで `VALID / INTERNAL_ONLY`、Internal TestFlightグループ `sun` 所属までread-backした。

APP2-007の人間判断不要な工程は完了。次の実機確認ではTestFlight Build 2を用いて「分野から解く」3分野のタップ、学習遷移、購入/復元等を受入確認できる状態。
