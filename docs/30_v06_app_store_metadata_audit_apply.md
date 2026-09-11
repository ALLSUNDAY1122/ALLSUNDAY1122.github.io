# AI引継ぎ帳 v0.6 App Store Connect日本語メタデータ監査・反映

作成日：2026年7月24日

## 目的

App Store ConnectのアプリレコードとVersion 0.6.0を作成した後、APIキーを使って既存の日本語ローカライズを監査し、確定済みメタデータとの差分を表示する。

初期動作は必ずドライラン。App Store Connectを変更するには、`--apply`と三つの完全一致確認をすべて指定する必要がある。

## 監査対象

- Bundle ID：`jp.allsunday.aihandoverlog`
- App Info Localization：日本語`ja`
- App Store Version：iOS `0.6.0`
- App Store Version Localization：日本語`ja`

## 更新対象

App Info Localization：

- App Name
- Subtitle
- Privacy Policy URL

App Store Version Localization：

- Description
- Keywords
- Promotional Text
- Support URL

## 自動化しない操作

- App ID登録
- 新規アプリレコード作成
- 新規Version作成
- 新規言語追加
- Build選択
- スクリーンショットアップロード
- App Privacy回答
- 年齢制限回答
- 価格・配信地域設定
- TestFlight設定
- App Review提出
- リリース

## 前提条件

1. Explicit App ID登録済み
2. App Store Connectアプリレコード作成済み
3. iOS Version `0.6.0`作成済み
4. 日本語ローカライズが存在
5. App Store Connect API key検証済み
6. PR #1661が明示的指示でマージ済み
7. Privacy URLとSupport URLが一般公開済み

## ドライラン

次のコマンドはApp Store Connectを更新しない。現在値との差分と公開URL状態をJSONへ保存する。

```bash
python3 scripts/audit_apply_app_store_metadata_ja.py \
  --api-key "/Users/ユーザー名/Secure/AuthKey_XXXXXXXXXX.p8" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000" \
  --metadata "config/app_store_metadata_ja_v06.json" \
  --output "app_store_metadata_audit.json"
```

ドライランでは`--confirm-bundle-id`、`--confirm-version`、`--confirm-apply`は不要。

## 反映前確認

`app_store_metadata_audit.json`で次を確認する。

- `mode`が`dry-run`
- Bundle IDが`jp.allsunday.aihandoverlog`
- Versionが`0.6.0`
- 対象Localeが`ja`
- `public_url_checks`が両方到達可能
- `urls_ready_for_apply`が`true`
- `diff`が意図した変更だけ
- `submission_performed=false`
- `build_selected=false`
- `screenshots_uploaded=false`

## 反映

ドライラン結果と公開URLを確認した後だけ実行する。

本番反映には次の四つがすべて必要。

1. `--apply`
2. `--confirm-bundle-id jp.allsunday.aihandoverlog`
3. `--confirm-version 0.6.0`
4. `--confirm-apply APPLY_METADATA`

```bash
python3 scripts/audit_apply_app_store_metadata_ja.py \
  --api-key "/Users/ユーザー名/Secure/AuthKey_XXXXXXXXXX.p8" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000" \
  --metadata "config/app_store_metadata_ja_v06.json" \
  --output "app_store_metadata_apply_result.json" \
  --apply \
  --confirm-bundle-id "jp.allsunday.aihandoverlog" \
  --confirm-version "0.6.0" \
  --confirm-apply "APPLY_METADATA"
```

いずれか一つでも一致しない場合は、APIへのPATCHを実行せず停止する。

## 部分反映への対応

ツールはAPIへのPATCH前に監査結果を保存する。各PATCH成功後にも同じ結果ファイルを更新する。

二つ目のPATCHなどで失敗した場合でも、`changes_applied`を確認することで、どのローカライズまで反映されたかを追跡できる。

再実行前に必ずドライランへ戻し、現在値との差分を再取得する。

## 停止条件

- Bundle ID一致のアプリが1件ではない
- App Infoが1件ではない
- 日本語App Info Localizationが1件ではない
- iOS Version 0.6.0が1件ではない
- 日本語Version Localizationが1件ではない
- 文字数制限超過
- KeywordsがUTF-8で100バイト超過
- Privacy URLまたはSupport URLが未公開
- API権限不足
- Bundle ID確認値が不一致
- Version確認値が不一致
- 固定確認文字列が`APPLY_METADATA`ではない

## 安全設計

- 既定は読み取り専用
- 更新には`--apply`と三重確認が必要
- 公開URLが到達不能なら更新を拒否
- API秘密鍵とJWTを出力しない
- PATCH前と各PATCH後に監査結果を保存
- Build、審査、公開へ進まない
- PR #1661とPR #870を自動マージしない

## 初回版の実行順

1. Apple画面でApp IDとアプリレコードを作成
2. Version 0.6.0と日本語ローカライズを作成
3. 資格情報検証スクリプトを合格させる
4. メタデータスクリプトをドライラン
5. PR #1661を明示的指示で公開
6. Privacy／Support URLをSafariで確認
7. ドライランを再実行
8. 差分を確認
9. 三重確認付き`--apply`
10. App Store Connect画面で入力結果を再確認
11. スクリーンショット、App Privacy、年齢制限、価格、配信地域を手動入力
