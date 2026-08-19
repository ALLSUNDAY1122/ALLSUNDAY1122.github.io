# APP2-003｜夜の書架｜申請状態再確認から再開

更新: 2026-08-19 12:35 JST
セッション: 夜の書架②
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`

## 結論

旧Notion正本の「審査中｜TestFlight Beta App Review審査待ち」「1.0 / Build 1」は現行状態ではなかった。App Store Connect APIで再監査し、現行は `1.1.0 / Build 3`、App Store Versionは `PREPARE_FOR_SUBMISSION`、Beta App ReviewとApp Store本審査はいずれも未提出であることを確認した。

自動で処理可能な申請準備は完了した。App Store Versionを `1.1.0` に整合し、VALID・未失効のBuild 3をApp Store Versionへ選択した。本審査App Review連絡先は、Apple内に既に保存されていたBeta App Review連絡先からApple内部で同期し、値自体はGitHubへ保存していない。Store説明、キーワード、Support URL、Privacy Policy URL、iPhoneスクリーンショット4枚も存在を確認した。

レビュー提出操作は実施していない。

## 開始時の正本再取得

- Notion台帳: 状態はすでに「公開準備」へ訂正済みだった。
- Notionアプリ正本: 旧記載として「審査中」「1.0 / Build 1 Beta App Review提出済み」が残存していた。
- GitHub `ALLSUNDAY1122/yoru-no-shoka` main: `app.json` は `1.1.0 / Build 3`。
- App Store Connect: App ID / Bundle IDをAPIで照合。
- Codemagic: API接続は成功したが `ALLSUNDAY1122/yoru-no-shoka` のApplication候補は0件。対象リポジトリはEAS設定を持つため、本タスクでCodemagic再Buildは行わなかった。

## App Store Connect監査｜自動補完前

- App: `夜の書架`
- App ID: `6794137637`
- Bundle ID: `io.github.allsunday1122.yorunoshoka`
- Build 3: `VALID` / 未失効
- Pre-release Version: `1.1.0`
- App Store Version: `1.0` / `PREPARE_FOR_SUBMISSION`
- App Store VersionのBuild選択: なし
- Build 3 Beta App Review Submission: 0件
- App Store Review Submission: 0件
- Beta App Review連絡先: 必須4項目あり
- App Store本審査Review連絡先: 必須4項目なし
- Store localization: 日本語あり
- 説明: あり
- キーワード: あり
- Support URL: あり
- Privacy Policy URL: あり
- iPhone screenshot: 4枚

## 自動補完

1. 対象App / Bundle / App Store Version / Build / Pre-release Versionを固定値でpreflight。
2. App Store Versionを `1.1.0` に整合。
3. Build 3をApp Store Versionへ選択。
4. VersionとBuild relationshipをAPI read-backして一致確認。
5. Beta App Review連絡先の存在を確認し、値をログ・GitHubへ出さずApp Store Review Detailへ同期。
6. 本審査Review連絡先の4項目が入力済みになったことをread-back確認。
7. Notion「夜の書架｜iOSアプリ正本」を「公開準備｜1.1.0 / Build 3、Beta App Review・本審査とも未提出」へ訂正し、再fetchで確認。

## 最終App Store Connect read-back

- App Store Version: `1.1.0`
- State: `PREPARE_FOR_SUBMISSION`
- Build relationship: Build 3 (`23521541-e269-4baf-800d-7830b94c36a1`)
- Build 3 Beta App Review Submission: 0件
- App Store Review Submission: 0件

補足: App Store Review Detailの連絡先値はPII保護のためsanitized readでは非表示。同期処理専用証跡で必須4項目すべて `true` を確認済み。

## 証拠ファイル

- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-asc-full.json`
- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-asc.json`
- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-version-build-fix.json`
- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-review-contact-sync.json`
- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-codemagic.json`

## 真正な人間ゲート

1. iPhone TestFlightでの実機受入確認。
2. EU Digital Services Actのトレーダー自己判定・申告。Appleはトレーダー該当性を開発者本人に自己評価させており、トレーダーの場合は連絡先確認等の本人確認工程があるため自動決定しない。
3. App Store本審査の最終 `Add for Review` / `Submit for Review`。ユーザー最終承認前には実行しない。

## Task判定

`HUMAN_REQUIRED`

理由: 技術的に自動化可能な申請準備は完了したが、実機受入、DSA自己判定・本人確認、最終審査提出承認は人間ゲートとして残るため。
