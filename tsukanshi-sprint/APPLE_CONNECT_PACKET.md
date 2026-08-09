# 通関士｜学びスプリント App Store Connect 入力票

更新日: 2026-08-09

このファイルは、App Store Connect / Codemagicで人が入力する値の正本です。秘密鍵・Issuer ID・Key ID・証明書などの秘密情報はGitHubへ保存しません。

## 1. 新規Appレコード
- Platform: iOS
- Name: `通関士｜学びスプリント`
- Primary Language: Japanese (Japan)
- Bundle ID: `jp.allsunday1122.tsukanshi`
- SKU: `tsukanshi-sprint-ios`
- User Access: Full Access（特別な制限が必要な場合のみ変更）
- Version: `1.0.0`

注意:
- Bundle IDはXcode側と完全一致させる。
- SKUはApp Store Connect作成後に変更できないため、上記を固定値として使用する。

## 2. In-App Purchase
- Type: Non-Consumable
- Reference Name: `通関士 プレミアム解放`
- Product ID: `jp.allsunday1122.tsukanshi.premium`
- Display Name (ja-JP): `プレミアム解放`
- Description (ja-JP): `模擬試験・苦手復習・申告書演習などのプレミアム機能を買い切りで解放します。`
- Family Sharing: OFF（初回）
- Price: App Store Connectで正式決定。アプリ表示はStoreKitの`displayPrice`を正本とする。
- Review Screenshot: TestFlight/Sandboxで課金画面を実機確認後に登録する。

Product IDは保存後に変更・再利用できないため、`jp.allsunday1122.tsukanshi.premium`以外では作成しない。

## 3. App Store表示
- Subtitle: `8問ずつ、通関士試験を反復`
- Primary Category: Education
- Secondary Category: Reference
- Support URL: `https://allsunday1122.github.io/tsukanshi-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/tsukanshi-sprint/privacy.html`
- Marketing URL: 初回は空欄可

説明文・キーワード等は `APP_STORE_METADATA_JA.md` を使用する。

## 4. App Privacy / Content Rights
現行実装の申告案:
- Tracking: No
- Third-party advertising: No
- Third-party analytics SDK: No
- Developer account/login: No
- 学習データの開発者サーバー自動送信: No
- 学習状態: 端末内保存
- 購入処理: Apple StoreKit
- 公式過去問本文: アプリへ同梱しない
- 税関公式ページ: 外部リンクのみ
- WCO由来実務資料: 転載しない

提出直前に実装差分を再監査する。

## 5. Codemagic / 署名
Codemagic integration名: `codemagic`

必要なApple側情報（GitHubへ保存しない）:
- App Store Connect API Key (.p8)
- Key ID
- Issuer ID
- Apple Distribution certificate / provisioning profile（Codemagic自動取得可）

Codemagic workflow: `tsukanshi-ios`
- Distribution type: `app_store`
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Internal TestFlight only export: ON
- `submit_to_testflight`: false
- `submit_to_app_store`: false

この構成では、本審査を自動提出しない。App Store Connectへのビルド送信後、内部TestFlightで実機確認する。

## 6. TestFlight合格条件
- Build処理成功
- iPhoneで起動
- ホーム／模試／記録／設定
- 通常学習・途中復帰
- 機内モードで教材起動
- 税関公式リンクが外部で開く
- 課金商品が取得でき、StoreKit表示価格が出る
- Sandbox購入成功
- アプリ再起動後もPremium維持
- 購入復元成功
- クラッシュなし
- 主要画面の表示崩れなし

## 7. 人の操作が必要な停止点
1. Appleログイン / 2FA
2. 最新契約の同意
3. 新規Appレコード作成
4. IAP作成・正式価格決定
5. CodemagicにAPIキーを登録
6. 初回signed IPA / TestFlight処理のApple側確認
7. iPhoneでSandbox購入・復元
8. 本審査提出直前の最終確認

これら以外の値・コード・監査結果はGitHub/Notion正本を優先する。
