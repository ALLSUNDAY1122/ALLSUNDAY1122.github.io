# APP2-003｜夜の書架｜次セッション引き継ぎ

更新: 2026-08-27 08:17 JST
セッション: 夜の書架② → 次セッションへ引き継ぎ
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去のASC/Codemagic結果は開始点であり正本ではない。次セッション開始時および各「次」で、Notion / GitHub / App Store Connect / Codemagicの実状態を必ず再取得すること。

## 最終確認済みの製品状態

- Pattern C「紙面・温かみ」は `ALLSUNDAY1122/yoru-no-shoka` mainへ統合済み。
- 現行release targetは `1.2.0 / Build 4`。
- Pattern C実装内容:
  - 紙面 / 深いセピア / 漆黒テーマ
  - 明るさ70–120%
  - 本文文字サイズ・行間
  - 明朝 / ゴシック
  - 設定値端末保存
  - 主CTA「今夜の一話を読む」
  - おまかせ / シリーズ / 書架の副導線
  - シリーズ/話者ガイド
  - 各作品カードに「この話を読む」
  - 検索 / 怖さ / 長さ / シリーズ絞り込み
  - 保存済み / 読了状態
  - 読書画面の戻る / タイトル / Aa / その他整理
  - 読書進捗バー

## App Store Connect｜最終確認 2026-08-22

- App Store Version `1.2.0`
- state `PREPARE_FOR_SUBMISSION`
- attached Buildなし
- Review Submission 0件
- Apple上の既存Buildは1/2/3のみ
- Build 4は当時未到着
- 日本語description / keywords / Support URL / Marketing URLあり
- App Review contact必須4項目あり
- Beta Review contact必須4項目あり
- Internal/Beta groups既存3グループ
- App Info subtitle / Privacy Policy URLあり
- iPhone screenshot 4枚あり。ただしPattern C刷新前の可能性があるため、Build 4実機受入後に現UIへ差し替えること。
- Age Rating現行監査: horror/fear `FREQUENT_OR_INTENSE`、territory表示は13+。legacy 12+を根拠にしない。

次セッションでは上記を必ずfresh readして差分判定すること。

## Codemagic｜GitHub接続問題は解消済み

GitHub Appへprivate repo `ALLSUNDAY1122/yoru-no-shoka` を許可済み。

壊れていた旧Codemagic Application 2件:
- `6a856ad0cfa731a85617d8fb`
- `6a89709c57ba683ac5fcdbe8`

はユーザー明示許可後に削除済み。

GitHub App経由で新規作成した正常Application:
- Codemagic App ID: `6a8af6e5a5c86907b00c2efd`
- `branches` read-backで `main`, `release/eas-build4-trigger`, `ui/pattern-c-paper-warm` を確認
- `main` と `codemagic.yaml` をCodemagic UI/APIの双方で認識済み

したがって「Branchが空」「repositoryが取れない」「GitHub App未接続」は解決済み。再度GitHub App再設定やApplication削除をしないこと。

## Codemagic Build診断

現行 `yoru-no-shoka/main/codemagic.yaml` workflow:
- `yoru-ios-diagnostic`
- `yoru-ios`

最初のBuild失敗原因:
- Codemagic標準Corepack 0.30.0が `pnpm@11.9.0` の新しい署名keyidを検証できず停止。

修正:
- Corepackを使わず `npm install --global --force pnpm@11.9.0` に変更。

診断Build `6a8afa087787725ef828f116` は `finished`。
以下までPASS済み:
1. pnpm 11.9.0導入
2. lockfile / dependency install
3. `pnpm ios:prepare`
4. Vite Pattern C web bundle生成
5. Capacitor iOS sync
6. Xcode release version同期
7. `1.2.0 / Build 4 / io.github.allsunday1122.yorunoshoka` audit

本番Build `6a8afb237787725ef828f194` の失敗点:

`=== stage: signing ===`
`Cannot save Signing Certificates without certificate private key`

つまりアプリコード / pnpm / Capacitor / versioningではなく、iOS署名private key不足のみが現時点の主要blocker。

証拠:
- `automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-codemagic.json`
- 現行 `ALLSUNDAY1122/yoru-no-shoka/main/codemagic.yaml`

## Apple署名preflight｜2026-08-23

read-only監査で以下を確認:

- Bundle resource ID: `K459HXU63D`
- Apple Distribution証明書はactive 3/3
- 夜の書架には既に有効なApp Store provisioning profileあり:
  - Profile ID `6598LFYDY3`
  - Name `*[expo] io.github.allsunday1122.yorunoshoka AppStore 2026-07-26T05:57:33.985Z`
  - state `ACTIVE`
  - certificate `B4WRC3G6V4`
  - expiration `2027-07-24T14:20:41Z`

重要:
- 新しいApple Distribution証明書を発行しない。
- 既存3証明書を安易にrevokeしない。他アプリで広く使用中。
- `B4WRC3G6V4` はExpo/EAS管理で、夜の書架profileと紐付いている。

証拠:
`automation/chatgpt-dispatcher/app-development-2/evidence/APP2-003-signing-preflight.json`

## 次セッションの最優先Macro Loop

開始時に必ずfresh read:
1. Notion アプリ開発台帳 / 夜の書架正本 / 標準公開フロー / 申請手順
2. `ALLSUNDAY1122/yoru-no-shoka` main / recent commits / `codemagic.yaml`
3. Dispatcher Queue / 本evidence / signing-preflight evidence
4. Codemagic App `6a8af6e5a5c86907b00c2efd` の現在状態と最新Build
5. ASC App `6794137637` のApp version / Builds / TestFlight / submissions
6. Apple certificates/profilesのfresh read

fresh read後、状態が変わっていなければ次を実行:

### Lane A｜既存EAS署名private keyの安全な再利用
- 中央repoに `EXPO_TOKEN` を使う既存EAS認証workflowがある。
- EAS側で `B4WRC3G6V4` に対応する夜の書架のDistribution Certificate/private keyを取得できるか確認。
- secret/private keyはGitHub/Notion/evidence/logへ一切出力しない。
- 可能ならephemeral runner内で取得し、Codemagic App `6a8af6e5a5c86907b00c2efd` のsecure variable groupへ直接保存。
- 既存成功例 `app2_010_touhan_signing` / `CERTIFICATE_PRIVATE_KEY` の設計を参考にするが、他アプリのprivate keyを夜の書架へ流用しない。
- `B4WRC3G6V4` とprivate keyが対応していることを安全に検証してから使用する。

### Lane B｜Codemagic署名workflowを確定
- secure groupを `yoru-ios` environment groupsへ追加。
- `keychain initialize`
- `app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE`（既存profile利用を優先。無条件`--create`は避ける）
- `keychain add-certificates`
- `xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'`
- signed IPA build
- IPA artifact/read-back

### Lane C｜Apple到着後
- App Store Connect upload/processing監視
- Internal TestFlightへ到達確認
- App Store Version 1.2.0へBuild 4をattach
- iPhone実機でPattern C受入確認
- Pattern C現UIのスクリーンショットへ更新
- Review Notes / Privacy / Age Rating / export compliance / DSA / Review contactをfresh audit
- 最終提出直前 `WAITING_FINAL_APPROVAL` まで自動で進める

## 禁止事項

- Codexは使わない。
- GitHub/Codemagic接続問題を再調査して壊れていないApplicationを削除しない。
- Apple Distribution証明書を推測でrevoke/createしない。
- secret/token/.p8/private keyをGitHub/Notion/log/evidenceへ保存しない。
- 旧Pattern C前スクリーンショットを新UI証拠としてPASSしない。
- `submit_to_app_store` / Add for Review / Submit for Reviewをユーザー最終承認なしで実行しない。

## 真正な人間Gate

自動工程が完了した後にのみ残す:
1. Build 4のiPhone TestFlight実機受入
2. DSAトレーダー自己判定・必要時本人確認
3. 最終 `Add for Review / Submit for Review` 承認

現時点の署名private key安全移送は、利用可能なEAS/Codemagic/GitHub secret経路で自動化可能性を先に追うこと。安易にHUMAN_REQUIREDとして止めない。

## Queueについて

Queue上のAPP2-003は現時点で `HUMAN_REQUIRED` の旧判定が残っている。次セッションはこれを正本扱いせずfresh read後に再判定すること。Task完了時または真正な人間Gate到達時のみ、自分のTaskだけをDONE/HUMAN_REQUIREDへ更新しremote read-backする。
