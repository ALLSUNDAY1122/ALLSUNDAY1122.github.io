# APP2-002｜呑み処アーケード｜完了証跡

- Task: `APP2-002`
- Session: `呑み処アーケード②`
- Worker role: `NOMIDOKORO`
- Completed: 2026-08-19 JST
- Codex: 未使用

## 開始時の正本再取得

Notion / GitHub / App Store Connect / Codemagic を開始時に再取得し、会話履歴を正本として扱わなかった。

実装正本は `ALLSUNDAY1122/nomikai-arcade-ios` branch `codex/nomikai-arcade-ios-release`。App Store Connect app id は `6794847479`、bundle id は `jp.allsunday1122.nomikaiarcade`。

開始時の ASC 実状態は App Store version `1.0.0` / Build 3 が `PENDING_DEVELOPER_RELEASE`。Build 4 は `VALID`。ASC の表示名称は `リレーアーケード`、subtitle は `1台で遊ぶ対戦ゲーム20選` だった。旧Buildには公開操作を行わない方針を維持した。

## 2026-08-18 UI指示の現行正本監査

現行 `nomikai-arcade.html` を再取得し、以下3点が既に正本へ成立していることを確認したため、HTMLを重複再実装しなかった。

1. 名称 `呑み処アーケード`
2. 上部マーク：3連提灯 `呑 / み / 処`
3. `〆にどうぞ` 文言なし

`NomikaiArcade.xcodeproj/project.pbxproj` の `CFBundleDisplayName` も `呑み処アーケード`。

## 回帰ゲート / 実装checkpoint

`ALLSUNDAY1122/nomikai-arcade-ios` の `codemagic.yaml` を更新し、2026-08-18 UI契約をCodemagicで機械検査するRelease Gateを追加した。

- target commit: `5d5fe549fd92c13599040fcbf6cb208201ac0788`
- Build number: Apple Build `5`
- `submit_to_testflight: true`
- `submit_to_app_store: false`
- 検査対象: title / site-title / 3連提灯 / `〆にどうぞ`不存在 / CFBundleDisplayName

## Codemagic / Build 5

Codemagic app id `6a66134ea9f671d548da335a`、workflow `ios-native`、branch `codex/nomikai-arcade-ios-release` で新Buildを実行。

- GitHub Actions build-only run: `32212081421` → success
- Codemagic build id: `6a85222c7c1d7b2c82dd2545`
- Apple Build number: `5`
- `submit_to_app_store`: false

ASCへ到達後、Build 5 id `f0a3be6b-8857-4c8d-9c31-00594aa6340f` をread-backし、最終 `processingState = VALID`、`buildAudienceType = APP_STORE_ELIGIBLE` を確認した。

## ASCメタデータ整合

承認済み `PENDING_DEVELOPER_RELEASE` のままでは name / subtitle のPATCHがHTTP 409 `ENTITY_ERROR.ATTRIBUTE.INVALID.INVALID_STATE` で拒否されることを実測した。

新Review Submission APIの `canceled=true` も、submission `da842467-2794-4717-a374-3d251d4d657c` が `COMPLETE` のためHTTP 409 `STATE_ERROR.ENTITY_STATE_INVALID / Resource is not in cancellable state`。

旧互換 `appStoreVersionSubmission` relationshipをread-backし、version submission id `7dcad63e-8c82-4d19-8dc5-873458bca58b` を確認。Appleの「Remove a version from App Review」に対応する scoped DELETE をAPP2-002固定IDにのみ実行した。

結果:

- version submission DELETE: HTTP `204`
- version state: `PENDING_DEVELOPER_RELEASE` → `DEVELOPER_REJECTED` → 最終 `PREPARE_FOR_SUBMISSION`
- ASC name: `リレーアーケード` → `呑み処アーケード`（PATCH 200）
- ASC subtitle: `1台で遊ぶ対戦ゲーム20選` → `みんなで遊べる宴会ゲーム19選`（同PATCH）
- selected build: Build 3 id `b11b4e2b-993f-4d7e-a6c5-92eef4dc9e93` → Build 5 id `f0a3be6b-8857-4c8d-9c31-00594aa6340f`（relationship PATCH 204）
- 再審査提出: `false`
- App Store公開: `false`

sanitized result: control repo main `automation/app2-002-asc-revise-result.json`。

## 最終ASC read-back

Release API Command Bus issue `#4299` / run `32212919892` で最終値を再取得。

- version `1.0.0`: `PREPARE_FOR_SUBMISSION`
- selected build: Build 5 (`f0a3be6b-8857-4c8d-9c31-00594aa6340f`)
- Build 5: `VALID`
- ja name: `呑み処アーケード`
- ja subtitle: `みんなで遊べる宴会ゲーム19選`

旧Build 3/4を公開する操作、`Release This Version`、新BuildのApp Review再提出は実行していない。

## Notion

呑み処アーケードの現行ページ `3b009c10-697d-8185-966f-eb68cdc663bf` に再開記録と最終完了値を追記済み。

## Task判定

APP2-002の要求範囲「名称/UI変更の現行正本確認 → 回帰確認 → 新Build → ASCメタデータ整合」は完了。App Reviewへの再提出/公開はこのTaskの範囲外として未実施。

**Status: DONE**
