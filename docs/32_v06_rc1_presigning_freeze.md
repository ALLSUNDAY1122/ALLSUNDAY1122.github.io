# AI引継ぎ帳 v0.6 RC1-pre-signing 固定記録

作成日：2026年7月24日

## 固定対象

- ソース固定コミット：`407a1c9c7c94c63b4d909c1500bc43244631c4ea`
- PR：#870
- Branch：`agent/ai-handover-log-v04-binary`
- Version：`0.6.0`
- Build：`6`
- Bundle ID：`jp.allsunday.aihandoverlog`
- Minimum iOS：`13.0`
- Device Family：iPhoneのみ
- Orientation：Portraitのみ
- `ITSAppUsesNonExemptEncryption=false`
- App-level Privacy Manifest：あり
- Data Collection：なし
- Tracking：なし

この固定コミット以降にドキュメント、検証ツール、運用ファイルを追加しても、提出対象アプリの動作ソースは上記コミットを基準とする。

## CI結果

同じ固定コミットに対して以下が成功した。

| Workflow | Run ID | 結果 |
|---|---:|---|
| Apple Secret Safety | `30058120951` | success |
| Release Tools CI | `30058120936` | success |
| App Store Screenshots | `30058121078` | success |
| v0.5 CI | `30058120935` | success |
| Final Tracker | `30058120941` | success |
| v0.5 iOS CI | `30058120939` | success |
| Device Release CI | `30058120945` | success |

## 固定Artifact

### Device Release

- Artifact ID：`8583703330`
- Digest：`sha256:0e6ef206193784ab5f8be82ad7bea086c7a8146aea66c1cc73113abfaa5fb46b`
- 内容：署名なしiPhone Release、署名なしArchive、ログ、TestFlight引継ぎ資料
- 用途：コンパイル・構成検証のみ
- App Store Connectへのアップロード：禁止

### App Store Screenshots

- Artifact ID：`8583533931`
- Digest：`sha256:f7ce5e9bc623f5b3bb9df16988a7a5788f40b8a5cb14195443b99735633c4316`
- 内容：iPhone 6.9インチ用スクリーンショット5枚と検証報告

## RC1マスターパック

- ファイル：`AI_Handover_Log_v0.6_RC1_PreSigning_Master_Pack_2026-07-24.zip`
- SHA-256：`eba95d46af4b44c5e2dc55164162def2591a1193df2c0a6835c66939d794eb0f`
- 秘密情報検査：合格
- Apple証明書、Provisioning Profile、App Store Connect API秘密鍵：含まない

## 公開ページ

- PR：#1661
- 状態：Draft、未マージ
- Privacy URL：未公開
- Support URL：未公開

明示的なユーザー指示なしにPR #1661をマージしない。

## 残る本人操作

1. Apple契約確認
2. Explicit App ID登録
3. App Store Connectアプリレコード作成
4. 公開ページのマージ判断
5. Apple署名付きArchive作成
6. Generate Privacy Report
7. Validate App
8. TestFlightアップロード
9. iPhone 16受入テスト40件
10. App Review提出

## 禁止事項

- 署名なしRunner.appまたは署名なしxcarchiveをアップロードしない
- Apple ID、パスワード、2ファクタ認証コード、証明書、Provisioning Profile、API秘密鍵をGitHub、PRコメント、ChatGPT、Notionへ貼らない
- 明示的なユーザー指示なしにPR #870またはPR #1661をmainへマージしない
