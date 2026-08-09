# Codex引継ぎ｜管理栄養士国家試験 学びスプリント

更新: 2026-08-09 22:23 JST

## 最上位正本
- Notion: 管理栄養士国家試験｜学びスプリント 開発正本
  - https://app.notion.com/p/3b609c10697d81fe9021fa01136faf58
- 学びスプリント標準手順 v2.2
  - https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- Golden Master / UI要件定義
  - https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 法律対応正本
  - https://app.notion.com/p/3b509c10697d81b58723ca46328f07dc

Codexは作業開始前に上記Notion正本を読むこと。GitHubとNotionが矛盾した場合、Notion正本に記載された優先順位に従う。

## リポジトリ
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App path: `kanrieiyoushi-sprint/`
- GitHub Pages: https://allsunday1122.github.io/kanrieiyoushi-sprint/

## 現在の確定状態
- Safari/PWA: v0.6.2
- 問題数: 600問
- 構成: 第1〜第3回 × 各200問
- 10分類、各回200問模試、苦手復習、途中復帰、履歴、5週間ヒートマップまで実装済み
- StoreKit 2＋iOS製品化 TECHNICAL GATE PASS
- iOS productization PR #4123 は main へマージ済み
- merge commit: `ccff97cabed2c54cd7b426cce98120a9a7f6d5b7`

## iOS実装
- SwiftUI + WKWebView
- 監査済みWeb資産をアプリへローカル同梱
- Bundle ID: `jp.allsunday1122.kanrieiyoushi`
- IAP: Non-Consumable
- Product ID: `jp.allsunday1122.kanrieiyoushi.premium`
- 価格表示: StoreKit `Product.displayPrice` のみ。固定価格禁止
- Entitlement: `Transaction.currentEntitlements`
- 更新監視: `Transaction.updates`
- 購入成功 / userCancelled / pending / revocation 対応
- 明示復元: `AppStore.sync()`
- Privacy Manifestあり
- 自動Beta Review / 自動App Store提出は禁止

## 課金範囲
無料:
- 第1回のみ
- 10分類 × 各6問 = 60問
- 今日のスプリント
- 無料範囲の分野別演習
- 無料範囲の苦手復習
- 基本記録
- 途中復帰

Premium:
- 全600問
- 200問模試 × 3
- 全苦手復習
- 詳細記録

GitHub Pages版は600問フルのまま維持する。課金ゲートはiOS同梱版だけに適用する。

## CI / 監査結果
- iOS Release Gate run: `31311911002` SUCCESS
- 600問Web回帰監査 run: `31311911011` SUCCESS
- 600問再監査 PASS
- Apple / StoreKit preflight PASS
- Privacy Manifest PASS
- XcodeGen PASS
- IAP Capability PASS
- Xcode 16.4 Release Simulator build PASS
- 生成 `.app` のWeb / native StoreKit bridge / Privacy / Assets同梱確認 PASS

### 問題監査の重要ルール
- 公式過去問の転載・軽微な言い換えをしない
- 公式問題は論点把握にだけ使い、独自作問する
- 一次資料を根拠とする
- 水増し禁止。数値だけ・語尾だけ変えた類似問題を増やさない
- 法令、食事摂取基準、統計、診療・栄養ガイドラインは基準日を保持
- 600問の内部監査PASSを、法的意見や専門家全文査読と誤認しない

## 正本AppIcon
Google Drive正本:
- filename: `04_管理栄養士国家試験.png`
- file ID: `11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4`
- 1024 × 1024
- 726223 bytes
- SHA-256: `294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f`

重要:
GitHub Actionsから匿名Google Drive URLを取得すると正本と異なるレスポンスになる。仮アイコンでArchive/TestFlightへ進まないこと。正本バイト列がRelease環境に入ったことをSHA-256で確認してから署名ビルドする。

## Codexが最初に行う作業
1. Notion正本、`kanrieiyoushi-sprint/app-store/IOS_RELEASE_STATE.json`、`RELEASE_CHECKLIST.md`、本ファイルを読む。
2. mainを最新化し、既存600問・Web版を壊さないことを確認する。
3. 正本AppIconをRelease環境へ安全に配置し、上記SHA-256を検証する。
4. App Store Connect側のApp record / Bundle ID / IAP / signing / Codemagic integrationの状態を確認する。認証や2FAで人間操作が必要なら、そこで止めて必要操作だけをユーザーへ提示する。
5. Signed IPAをInternal TestFlightへ上げられる状態まで進める。
6. 実機で以下を確認する。
   - 起動
   - 無料60問の境界
   - StoreKit `displayPrice`
   - Sandbox購入
   - userCancelled
   - pending
   - 購入復元
   - 再起動後のentitlement
   - Premium 600問解放
   - 模試3回解放
   - revocation時の無料範囲復帰
7. FAILがあれば、標準手順v2.2どおり「変更 → 対応品質ループ → 監査 → FAIL修正 → 再監査」を完了する。
8. TestFlight実機確認完了後、Notion正本・アプリ開発台帳・GitHub Release Stateを同期する。

## 実装ファイルの起点
- `kanrieiyoushi-sprint/ios/App.swift`
- `kanrieiyoushi-sprint/ios/native-storekit.js`
- `kanrieiyoushi-sprint/ios/prepare-ios.sh`
- `kanrieiyoushi-sprint/ios/project.yml`
- `kanrieiyoushi-sprint/ios/codemagic-kanrieiyoushi.yml`
- `kanrieiyoushi-sprint/ios/PrivacyInfo.xcprivacy`
- `kanrieiyoushi-sprint/app-store/IOS_RELEASE_STATE.json`
- `kanrieiyoushi-sprint/app-store/RELEASE_CHECKLIST.md`
- `kanrieiyoushi-sprint/app-store/APPLE_CONNECT_PACKET.md`
- `kanrieiyoushi-sprint/app-store/APP_REVIEW_NOTES_JA.md`
- `kanrieiyoushi-sprint/app-store/STOREKIT_TEST_PLAN.md`

## 完了条件
Codex側の完了条件は「コードがビルドできる」ではない。以下をすべて満たしたときのみ次ゲートへ進む。
- Signed Internal TestFlight build
- 正本AppIcon
- iPhone実機起動
- 無料60問境界PASS
- Sandbox購入PASS
- 購入復元PASS
- pending/cancel PASS
- Premium600問 / 模試解放PASS
- 重大UI回帰なし
- GitHub / Notion状態同期

App Store本審査への提出はユーザー承認なしで行わない。
