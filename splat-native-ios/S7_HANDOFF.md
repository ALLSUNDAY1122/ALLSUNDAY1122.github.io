# Scaniverse同等化 S7 Handoff

更新日: 2026-08-15

## 担当範囲

S7は `Map / Discover / Account / Sharing Backend` を担当する。

実装対象:

- メールアドレス/パスワード認証
- 最小プロフィール
- `private` / `unlisted` / `public` の公開範囲
- 生成済み `.splat` とプレビューのクラウド保存
- 共有URLとブラウザ3Dビューア
- 実投稿だけを表示するDiscover
- 明示的に位置情報を付与した公開投稿だけを表示するMap
- 他ユーザーの公開3DをiOS内で開く
- いいね
- 投稿報告
- 投稿者ブロック
- 所有者による公開解除・削除
- アカウントとクラウドデータの削除
- 公開レート制限
- UGC安全確認とサーバー側テキスト拒否
- 報告済み投稿の即時非表示・再公開保留

## 実装先

### iOS

- `SplatNative/ScanLabBackend.swift`
- `SplatNative/ScanLabShellView.swift`
- `SplatNative/ScanLabAccountView.swift`
- `SplatNative/PublishScanView.swift`
- `SplatNative/SplatNativeApp.swift`
- `SplatNative/PrivacyInfo.xcprivacy`

### Browser viewer

- `viewer/index.html`
- `viewer/viewer.css`
- `viewer/viewer.js`

### Backend source of truth

Supabase project ref: `gybchnyqlqwmajwkhsly`

- `supabase/migrations/20260815015516_scanlab_s7_social_backend_v1.sql`
- `supabase/migrations/20260815015555_scanlab_s7_harden_moderation_v2.sql`
- `supabase/migrations/20260815015636_scanlab_s7_asset_path_guard_v3.sql`
- `supabase/migrations/20260815020313_scanlab_s7_close_base_tables_v4.sql`
- `supabase/migrations/20260815020950_scanlab_s7_private_policy_helpers_v5.sql`
- `supabase/migrations/20260815021011_scanlab_s7_fk_indexes_v6.sql`
- `supabase/migrations/20260815021337_scanlab_s7_ugc_safety_v7.sql`
- `supabase/functions/scanlab-public/index.ts`
- `supabase/functions/scanlab-publish/index.ts`
- `supabase/functions/scanlab-delete-account/index.ts`

サーバー秘密鍵はGitHub/iOSへ保存しない。クライアントはSupabase publishable keyのみを使用する。

## セキュリティ境界

- `scanlab_profiles`, `scanlab_scans`, `scanlab_likes`, `scanlab_reports`, `scanlab_blocks` はRLS有効。
- `scanlab_scans` の匿名直接SELECT権限はない。
- クライアントは `moderation_status` を更新できない。
- Storage bucket `scanlab-assets` は非公開、128 MiB上限、所有者UUID配下だけ書込/読込/削除可能。
- public/unlistedの閲覧はEdge Functionが短時間署名URLを発行する。
- private投稿は共有URLを発行しない。
- public投稿には位置情報・公開場所・プライバシー・権利確認が必須。
- public/unlistedにはUGC安全確認が必須。
- 共有公開は1時間10件まで。
- 有効な報告が入った投稿は即時 `hidden` + `pending` へ移し、所有者自身の再公開では解除できない。
- ブロックした投稿者は認証付きMap/Discover feedから除外する。

## 2026-08-15 機械監査

- Supabase Security Advisor: 0 findings。
- 全5テーブルのRLS有効をSQLで確認。
- `anon` の `scanlab_scans` 権限が空であることをSQLで確認。
- `authenticated` のscan UPDATE列に `moderation_status` が含まれないことをSQLで確認。
- Storageが `public=false`, `file_size_limit=134217728` であることをSQLで確認。
- Performance Advisorはデータ未投入のための `unused_index` INFOのみ。FK未索引警告はv6で解消済み。

## Parity判定

S7のコード・DB・Storage・Edge Function・公開Web viewerは実装済みだが、実機E2E前なので `PARITY` にはしない。

現段階は `PARTIAL`。iOS Simulator CIがPASSした後でも、下記の実機/別ブラウザ確認が完了するまでは最大 `NEAR_PARITY` とする。

## Human-only gate

次の確認だけは実iPhone/TestFlightと実アカウントを必要とする。

1. ローカルで新規3Dを生成する。
2. Accountで登録/ログインする。
3. private保存し、共有URLが発行されないことを確認する。
4. unlisted投稿し、Safariまたは別端末ブラウザで専用URLから3Dを操作する。
5. public投稿し、明示的な位置設定と安全確認なしでは投稿できないことを確認する。
6. Map/Discoverに実投稿だけが出ることを確認する。
7. 別アカウントでいいね、報告、ブロックを確認する。
8. 報告後に対象投稿がMap/Discover/共有URLから取得不能になることを確認する。
9. 所有者の公開解除・個別削除後に共有URLが無効になることを確認する。
10. アカウント削除後にプロフィール、DB行、Storage資産が残らないことを確認する。

この10項目を実証して初めてS7の `PARITY` 判定へ進む。
