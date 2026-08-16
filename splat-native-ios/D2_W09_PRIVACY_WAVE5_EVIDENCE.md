# D2-W09 Privacy Wave5 Evidence — 2026-08-17

## Scope

D2-009 / `scaniverse/d2-w09-privacy`。担当は Privacy Manifest / App Review説明 / 権限文言 / D2公開機能のprivacy整合 / D2回帰gate のみ。

## Canonical refresh

Wave開始時にNotion `Scaniverse同等化｜4開発班＋統合本部 v2.0`、GitHub D2 base / W01 / W02 / W03 / W05 / W06 / W07 / W08 / W09、統合PR #4145、本番Supabaseを再取得した。

- base `scaniverse/d2-share-discover`: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
- W09 start HEAD: `5652c56c3b6af4559e69e6a77d700526903356fd`
- W01: `8e922b20788740ec43c4208535363c8d70b3460c` / ahead 5
- W02: base同一
- W03: `2abab91ff104bc1c32b05c9e075fe1a6c26c2f39` / ahead 6
- W05: `7537e933331e9756ba60d5a32208a1f3021db9dd` / ahead 5
- W06: `fb1048bd7e3c5594bdb2c7761e8655470555f7ac` / ahead 5
- W07: base同一
- W08: `41b216fbf974d3333e29c5750414eb2d6ea0dda2` / ahead 6

W01 Wave4はsignup confirmation resendを追加したが、端末に保存するのは最後の送信時刻だけで、新しいApp Privacy data typeは増えない。W03 Wave4は公開後visibility変更でPublic→Unlisted/Private時にgeodata削除・share token rotationを追加。W08 Wave4はreport/block/publish rate-limitをproductionへ追加し、rate-limit bucketは`auth.users`への`ON DELETE CASCADE`を持つ。

## Largest privacy gap found

Wave4まではApp Store Connect privacy回答とアプリPrivacy Manifestのdata type集合を完全一致させていた。しかしAppleの現行App Privacy説明は、App Store Connect回答にはアプリ自身だけでなくthird-party partnersが収集するデータも含めるよう要求する。一方Privacy Manifestはアプリとthird-party SDKのmanifestを分担できる。

Supabaseの現行Auth Audit Logs documentationを確認すると、signup/login/password change/reset/email verification/token refresh/logout等の認証イベントは自動的に監査ログへ記録され、`user_id`、`ip_address`、`user_agent`、event/action、timestamp、provider metadata等を含む。ログは既定でPostgres `auth.audit_log_entries` と外部log storageに保持される。

Appleは保存するIPアドレスについて、用途に応じてlocation / device ID / diagnostics等の関連data typeを申告するよう案内している。Scan LabではIP/User-Agentを広告・位置推定目的ではなく認証、セキュリティ、不正利用防止、障害調査に使うため、App Store Connect上は `Other Diagnostic Data` / `App Functionality` / `Linked to User = YES` / `Tracking = NO` とするのが最も保守的で実態に近い。

## Production verification

Supabase project `gybchnyqlqwmajwkhsly` をread-only確認した。

- `auth.audit_log_entries` columns: `instance_id`, `id`, `payload`, `created_at`, `ip_address`
- Wave時点のaudit rowsは0。実auth userがまだ存在しないためであり、機能上の非収集を意味しない。
- `auth.audit_log_entries` には `auth.users` へのforeign key / ON DELETE CASCADEが存在しない。primary keyとnot-null checksのみ。

したがって「アカウント削除と同時に認証監査ログも必ず消える」という説明は保証できない。アプリ所有のscan/profile/social recordsとSupabase Authのsecurity/audit log retentionを分けて説明する必要がある。

## Pinned SDK check

W01が固定している `supabase-swift` revision `21d3aaf21ee98f41611f9f75070489fc8b23d882` はSupabase Swift 2.55.1。固定revisionのrecursive treeを確認したが `PrivacyInfo.xcprivacy` は見つからなかった。

ただし今回追加する監査ログはSwiftコードが独自にdiagnostic streamを生成しているものではなく、Supabase Auth serviceが認証要求を処理する際のthird-party-partner側保持である。このためApp Store Connect転記正本へpartner-only dataとして追加し、アプリPrivacy Manifest自体へ偽のapp-side diagnostic collectionを追加しない。

## Implementation

1. `APP_STORE_PRIVACY_RESPONSES.json`
   - schema version 2。
   - existing Manifest-backed 8 typesを維持。
   - `NSPrivacyCollectedDataTypeOtherDiagnosticData` / `Other Diagnostic Data` を追加。
   - `source_scope=third_party_partner`, `manifest_declared=false`。
   - purpose `App Functionality`, linked=true, tracking=false。
2. `privacy.html`
   - Supabase Auth audit/security logsを明示。
   - user ID / IP / User-Agent / auth event/time等を含み得ること、用途をauth/security/abuse prevention/diagnosis/complianceに限定することを明記。
   - account削除時に監査ログの即時削除を保証しないretention boundaryを追加。
3. `privacy-choices.html`
   - account/cloud deletionのself-service説明へ同じaudit-log retention boundaryを追加。
4. `APP_REVIEW_NOTES_JA.md`
   - Manifest 8 typesとApp Store Connect 9 typesを明確に分離。
   - third-party partner `Other Diagnostic Data` を追加。
5. `APP_STORE_METADATA_JA.md`
   - Nutrition Label転記表を9 typesへ更新。
   - Manifest完全一致ではなくManifest ⊂ App Store answers contractへ変更。
6. `scripts/test_d2_privacy_contract.py`
   - Manifestはapp-side 8 types exact。
   - App Store answersは9 types exact。
   - Manifest typesがApp Store answersへ包含されることを要求。
   - partner diagnostic rowのscope / purpose / linked / tracking / evidenceをgate。
   - policy/review/choicesのaudit-log retention wordingをgate。

Privacy Manifest `SplatNative/PrivacyInfo.xcprivacy` 自体は変更しない。

## Harsh review

### Rejected: App Store answers == Privacy Manifest を維持
AppleはApp Store Connectでthird-party partner collectionまで回答させるため、将来も完全一致を強制するとpartner-only collectionの過少申告を誘発する。却下。

### Rejected: Supabase audit IPをPrecise/Coarse Locationとして重複申告
Scan LabはAuth audit IPから位置情報を生成・利用していない。AppleはIPの用途に応じたdata type選択を求める。explicit public geotagのPrecise Locationとは別で、security/diagnostic用途として `Other Diagnostic Data` が適切。却下。

### Rejected: Device IDを追加
User-AgentやIPは存在するが、stable device-level identifierを収集している証拠はない。Device IDを追加する根拠が不足。却下。

### Rejected: account deleteでaudit logsも消えると断言
production `auth.audit_log_entries` にauth.users FK/cascadeがなく、Supabase docsもexternal log storageを説明しているため保証不能。削除境界を分離した。

## Regression expectations

Branch update後の `Splat Native iOS Build` で以下を確認する。

- Static checks
- D2 privacy alignment contracts
- S2 reconstruction contracts
- project/resource generation
- SwiftPM resolve
- msplat Simulator smoke build
- iPhone Release compile without signing

不要な中間push/PR/CIは発生させず、全blob/treeを作成後にW09 refを1回だけfast-forwardする。

## Remaining external gates

- W03 visibilityのgeodata removalをW09 policyへ反映するのは、W03がHQ/D2へ統合され実装が正本になった時点で行う。現W09単体へ先行断言しない。
- W01 real auth/email callback E2Eはtest identityとhosted Auth configuration待ち。
- W02/W07はbase同一で、trusted upload integration / owner lifecycle full gateが未完了。
- W05/W06/W08のcross-worker integration後、final privacy reconciliationが必要。
- App Store Connect実画面への9項目転記、公開Privacy/Privacy Choices/Support URL reachability、最終Nutrition Label確認は統合・本審査時のexternal gate。
