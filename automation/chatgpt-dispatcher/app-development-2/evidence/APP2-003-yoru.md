# APP2-003｜夜の書架｜次セッション引き継ぎ

更新: 2026-08-28 13:05 JST
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去結果は開始点であり正本ではない。開始時および各「次」で Notion / GitHub / App Store Connect / Codemagic をfresh readすること。

## 現在状態｜2026-08-28 13:05 JST

- Pattern C「紙面・温かみ」はmainへ統合済み。
- Build 4は実機でUX不具合5点が判明し受入FAIL。
- Build 5 (`6a90c5121f14c2b8e5f8cfe1`) はIPA/ASC VALIDまで成功したが、ユーザー再確認で「何も解決していない」と判定され、**実機受入FAIL**。
- Build 5失敗の根本原因を確定した。iOS Capacitor実エントリーポイント `native/main.tsx` が `HorrorLibrary` と `app/globals.css` のみを読み込み、前回修正の `app/pattern-c-fixes.css` と `ReaderRuntimeGuards` はNext.js Web側にしか接続されていなかった。そのためBuild 5 IPAには5修正が入っていなかった。
- native entrypointを修正し、`ReaderRuntimeGuards` をmount、`pattern-c-fixes.css` をimport、`html.app2-reader-fixes-v3` revision classを付与した。
- 5つの物理修正CSSをrevision class配下へscopeし、生成native bundleを検査するCodemagic Gateを追加した。
- 現行実機再テスト対象は **1.2.0 / Build 6**。
- 成功Codemagic Build ID: `6a9105fde0c3191da504c2c7`
- source commit: `0083095e354fb96a22afadba8a7f174bc5dc8220` (`APP2-003: verify scoped native corrective selectors`)
- Codemagic status: `finished`
- IPA: `12,809,854 bytes`, version `1.2.0`, build `6`
- App Store Connect Build resource: `e831d8cf-fa07-463f-b948-c891e1554902`
- Apple processingState: `VALID`
- buildAudienceType: `INTERNAL_ONLY`
- App Store Version `1.2.0`: `PREPARE_FOR_SUBMISSION`
- Review Submission: 0件
- 本審査候補workflowはBuild 7へ退避済み。Build 6実機PASS前には起動・attach・submitしない。

## Build 4/5で報告された5不具合

1. 読むときに話の途中位置から表示される。
2. 話によっては本文スクロールができない。
3. 読了まで進まないと前画面／ホームへ戻りにくい。
4. 書架で下へスクロールしても検索・絞り込みUIがsticky表示され続け邪魔。
5. 「この話を読む」CTAが見えにくい。

## Build 6 corrective layer

- `native/main.tsx` が `ReaderRuntimeGuards` と `pattern-c-fixes.css` を実際に読み込む。
- Reader mount／作品切替時にscrollTop/scrollLeftを即時＋requestAnimationFrame後に再同期する。
- Reader overlayをiOS/WKWebView向けの単一縦スクロールコンテナとして明示。
- Reader toolbarを常時fixed化し、戻る操作を本文位置に依存させない。
- `.library-tools` のstickyを廃止。
- 各カードの「この話を読む」を48px以上・高コントラスト・太字の主CTAへ強化。

## Native bundle Gate / IPA proof

Codemagic Build 6では `pnpm ios:prepare` 後、署名前に `scripts/verify-native-ui-revision.mjs` を実行する。

Gate PASSログ:
- `native UI audit PASS: dist-native contains native JS revision and all scoped physical-fix selectors`
- `native UI audit PASS: ios/App/App/public contains native JS revision and all scoped physical-fix selectors`

完成IPAをさらに直接監査:
- `Payload/App.app/public/assets/index-SFHvZisG.js` に `app2-003-reader-fixes-v3` が存在。
- `Payload/App.app/public/assets/index-DGGh1Lk6.css` に `app2-reader-fixes-v3` が存在。
- 同CSS内で以下4系統のscoped selectorを全て確認:
  - `html.app2-reader-fixes-v3.reader-overlay`
  - `html.app2-reader-fixes-v3.reader-toolbar`
  - `html.app2-reader-fixes-v3.library-tools`
  - `html.app2-reader-fixes-v3.story-card.story-read-button`
- `all_scoped_selectors_present=true`

よってBuild 5と異なり、Build 6では修正レイヤーが実際のiOSアプリバンドルに内包されていることを機械確認済み。ただし、これは物理UX PASSの代替ではない。

## Build 6 IPA / Privacy

- `CFBundleIdentifier = io.github.allsunday1122.yorunoshoka`
- `CFBundleShortVersionString = 1.2.0`
- `CFBundleVersion = 6`
- `MinimumOSVersion = 15.0`
- `ITSAppUsesNonExemptEncryption = false`
- app / Capacitor / Cordova の3 `PrivacyInfo.xcprivacy` は `NSPrivacyTracking=false`
- Tracking Domains / Collected Data Types / Accessed API Types は空

## 署名資産

- Profile `6598LFYDY3`: ACTIVE / IOS_APP_STORE
- Certificate `B4WRC3G6V4`: IOS_DISTRIBUTION、expiration `2027-07-24T14:20:41Z`
- 既存資産を継続利用。新しい証明書を推測で発行/revokeしない。

## 現在の真正な人間Gate

**iPhone TestFlightで1.2.0 / Build 6を再受入すること。**

最低限の再確認:
- どの作品も必ず冒頭から開く
- 長短を含む複数作品で最後まで上下スクロールできる
- 読書途中のどの位置でも上部「戻る」／その他メニューから離脱でき、ホームへ戻れる
- 書架を下へスクロールすると検索・絞り込みUIが上へ流れて消える
- 「この話を読む」が一目で主要操作と分かる
- テーマ／明るさ／文字サイズ／行間／フォント切替が維持される
- 白画面、フリーズ、クラッシュがない

Build 6を「解消済み」とは実機PASSまで判定しない。PASS後のみ本審査用 `APP_STORE_ELIGIBLE` Build 7 → 現UIスクリーンショット → Review Notes / DSA / submission auditへ進む。

## 禁止事項

- Codexは使わない。
- secret/token/.p8/private keyをGitHub/Notion/evidence/logへ保存しない。
- Build 4/5を受入済みとして再利用しない。
- Build 6をApp Store本審査用として誤認しない（`INTERNAL_ONLY`）。
- 旧スクリーンショットを現UI証拠としてPASSしない。
- `Add for Review / Submit for Review` をユーザー最終承認なしで実行しない。

## Queue判定

APP2-003は `HUMAN_REQUIRED` が正しい。現在の人間Gateは **Build 6 TestFlight実機再受入**。
