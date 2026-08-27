# APP2-003｜夜の書架｜次セッション引き継ぎ

更新: 2026-08-28 07:42 JST
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去結果は開始点であり正本ではない。開始時および各「次」で Notion / GitHub / App Store Connect / Codemagic をfresh readすること。

## 現在状態｜2026-08-28 07:42 JST

- Pattern C「紙面・温かみ」はmainへ統合済み。
- Build 4はInternal TestFlightへ到達したが、2026-08-28のiPhone実機確認でUX不具合5点が判明し **受入FAIL**。
- 5点を修正した現行再テスト対象は `1.2.0 / Build 5`。
- Codemagic App ID: `6a8af6e5a5c86907b00c2efd`
- 修正版Codemagic Build ID: `6a90c5121f14c2b8e5f8cfe1`
- Build 5 source commit: `7a46e750f05daf0fcafec220708ca93c77136394`
- Codemagic status: `finished`
- `App.ipa` 生成成功、size `12,809,176 bytes`、version `1.2.0`、build `5`
- App Store Connect Build resource: `c0571857-6474-4b86-90b3-a3969f8ad3aa`
- Apple processingState: `VALID`
- buildAudienceType: `INTERNAL_ONLY`
- App Store Version `1.2.0`: `PREPARE_FOR_SUBMISSION`
- Review Submission: 0件
- 本審査候補workflowはBuild 6へ退避済み。Build 5実機PASS前には起動・attach・submitしない。

## Build 4 実機FAIL｜2026-08-28

ユーザー実機動画と報告で以下を確認したため、Build 4の受入PASSは成立しない。

1. 読むときに話の途中位置から表示される。
2. 話によっては本文スクロールができない。
3. 読了まで進まないと前画面／ホームへ戻りにくい。
4. 書架で下へスクロールしても検索・絞り込みUIがsticky表示され続け邪魔。
5. 「この話を読む」CTAが見えにくい。

## Build 5 修正内容

- `app/ReaderRuntimeGuards.tsx` を追加。Reader mount／作品切替時に `scrollTop=0` を即時＋2回のrequestAnimationFrame後にも再同期し、WKWebViewの旧scroll offset保持を防止。
- Reader overlayを `100dvh`、`overflow-y: scroll`、`touch-action: pan-y`、`-webkit-overflow-scrolling: touch` に明示し、iOSの縦スクロールを安定化。
- Reader toolbarを常時fixed化。戻るボタンへ「戻る」ラベルを追加し、戻る／Aa／その他メニューへ本文位置に関係なく到達可能にした。ホーム導線はその他メニュー内に維持。
- `.library-tools` のstickyを廃止し、作品カード閲覧中に検索・絞り込みUIが追従しないよう変更。
- 各カードの「この話を読む」を48px以上、高コントラスト背景、太字の主CTAへ強化。
- Internal TestFlight workflowをBuild 5へ繰り上げ、本審査候補workflowはBuild 6へ変更。

主なapp repo commits:
- `12d8fa6982153281811210ab07c2fc5873521ad3` APP2-003: add iOS reader scroll-position guard
- `0dadc230ef719a5bf4b5e1f1d574633e77be73dc` APP2-003: mount reader runtime guard
- `680a0e6420c9d07e9b2322cac2bbf7c0b49a38e5` APP2-003: fix reader navigation, scrolling, library tools and CTA
- `7a46e750f05daf0fcafec220708ca93c77136394` APP2-003: reserve Build 5 for revised internal TestFlight

## 既に解消済みのBuild blocker

1. Corepack / pnpm署名不整合
   - Corepackを使わず `npm install --global --force pnpm@11.9.0` へ変更済み。
2. iOS署名private key不足
   - 既存Apple Distribution証明書 `B4WRC3G6V4` とprofile `6598LFYDY3` を安全に利用できる状態へ復旧済み。
3. `xcode-project use-profiles` の対象過多
   - `--project "$CM_BUILD_DIR/$XCODE_PROJECT"` を明示し、`ios/App/App.xcodeproj` のみに限定して解消。

## 署名資産｜2026-08-28 fresh read

- Bundle resource ID: `K459HXU63D`
- Bundle identifier: `io.github.allsunday1122.yorunoshoka`
- Profile ID: `6598LFYDY3`
- Profile state: `ACTIVE`
- Profile type: `IOS_APP_STORE`
- Certificate ID: `B4WRC3G6V4`
- Certificate type: `IOS_DISTRIBUTION`
- Certificate expiration: `2027-07-24T14:20:41Z`

新しいApple Distribution証明書を推測で発行/revokeしない。

## Privacy / Export compliance

Build 4実IPAで以下を確認済み。Build 5は同一依存関係・同一privacy宣言のUX修正版であり、Build 5実機PASS後、本審査用Build 6でも再監査する。

- app / Capacitor / Cordova の3 `PrivacyInfo.xcprivacy` は `NSPrivacyTracking=false`
- Tracking Domains / Collected Data Types / Accessed API Types は空
- `ITSAppUsesNonExemptEncryption=false`

## 現在の真正な人間Gate

**iPhone TestFlightで1.2.0 / Build 5を再受入すること。**

最低限の再確認:
- どの作品も必ず冒頭から開く
- 長短を含む複数作品で最後まで上下スクロールできる
- 読書途中のどの位置でも上部「戻る」／その他メニューから離脱できる
- ホームへ戻れる
- 書架を下へスクロールすると検索・絞り込みUIが上へ流れて消える
- 「この話を読む」が一目で主要操作と分かる
- テーマ／明るさ／文字サイズ／行間／フォント切替が維持される
- 白画面、フリーズ、クラッシュがない

Build 5がPASSした場合のみ、本審査用 `APP_STORE_ELIGIBLE` Build 6 → Pattern C現UIスクリーンショット → Review Notes / DSA / submission auditへ進む。

## 禁止事項

- Codexは使わない。
- secret/token/.p8/private keyをGitHub/Notion/evidence/logへ保存しない。
- Build 4を受入済みとして再利用しない。
- Build 5をApp Store本審査用として誤認しない（`INTERNAL_ONLY`）。
- 旧Pattern C前スクリーンショットを現UI証拠としてPASSしない。
- `Add for Review / Submit for Review` をユーザー最終承認なしで実行しない。

## Queue判定

APP2-003は `HUMAN_REQUIRED` が正しい。現在の人間Gateは **Build 5 TestFlight実機再受入**。
