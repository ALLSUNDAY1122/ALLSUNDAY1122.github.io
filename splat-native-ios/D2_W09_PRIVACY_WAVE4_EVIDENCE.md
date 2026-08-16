# D2-009 Privacy Wave 4 Evidence

- Date: 2026-08-17 JST
- Worker: D2-009
- Branch: `scaniverse/d2-w09-privacy`
- Base: `scaniverse/d2-share-discover`
- Wave start worker HEAD: `325f8b1fc976955b669fdc1f93177dddeb9f349b`
- Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
- Scope: App Store Privacy Nutrition Label transfer contract / generated preview media disclosure / User Privacy Choices URL

## Canonical refresh

Wave開始時にNotion「Scaniverse同等化｜4開発班＋統合本部 v2.0」、GitHub統合PR #4145、D2 base、D2-W09 branchを再取得した。baseは `c47329211f5ec9495f29d0c171dbfe95323f5bd9`、W09はWave 3完了HEAD `325f8b1fc976955b669fdc1f93177dddeb9f349b` のままで、Wave 1〜3の完了内容は再実装していない。

並行Workerも再確認した。

- W01はauth confirmationに加えてpassword recovery callbackまで実装済み。ただしproduction Supabase Auth URL Configurationと実メールE2Eは未完了。
- W03はowner visibility UIの正確な状態表示を追加。
- W05/W06はMap/Discoverのbbox/cursor/fresh-openを強化。
- W08はpublish/report/block mutationのtoken-bucket rate limitを追加。新しいApp Privacy data typeを必要とする追加データ種別は見当たらず、既存User ID / Product Interaction契約の範囲内。
- W07はbaseと同一。

他Worker branchは変更していない。

## Apple primary-source audit

2026-08-17時点でApple Developer一次資料を再確認した。

- App Store Connect App Privacyは、収集する各data typeについて用途、ユーザーへの紐付け、tracking有無を回答し、実装変更に応じて継続更新する必要がある。
- Privacy Policy URLは必須。User Privacy Choices URLは任意で、ユーザーがデータへのアクセス・削除・変更等を行うページを指定できる。
- `NSPrivacyCollectedDataTypePhotosorVideos` は正式なPrivacy Nutrition Label data type。
- AppleのApp Privacy Detailsは、アプリ機能が特定のmedia typeをアップロードする場合、その具体的なmedia typeを開示する考え方を示している。

## Newly detected mismatch

Wave 3までのPrivacy Manifest / App Store正本は7 data typesだった。

一方、実装を再追跡すると次の経路が存在する。

1. `ScanModel` は生成完了時、trainerのcamera index 0 renderから `previewImage` を生成する。
2. `ScanLabShellView` はその `model.previewImage` を `PublishScanView` へ渡す。
3. `ScanLabBackend+TrustedPublish.swift` は明示クラウド共有時、previewが存在すればJPEG化されたファイルを `preview.jpg` / `image/jpeg` としてSupabase Storageへ保存する。
4. したがってpreviewは端末内だけの一時処理ではなく、ユーザーアカウント・共有scanに紐づいてオフデバイス保存される画像である。

撮影元画像そのものは公開UIから送信しないが、生成preview画像について `Photos or Videos` が未申告だった。

## Fix

### `SplatNative/PrivacyInfo.xcprivacy`

`NSPrivacyCollectedDataTypePhotosorVideos` を追加。

- Linked to User = true
- Tracking = false
- Purpose = App Functionality

既存7種、Tracking=false、tracking domains空、FileTimestamp `C617.1`は維持。

### `APP_STORE_PRIVACY_RESPONSES.json`

App Store Connectへ転記する機械可読正本を新設した。

8 data typesすべてについて以下を固定する。

- Apple manifest type
- App Store表示名
- collected=true
- purpose=App Functionality
- linked_to_user=true
- used_for_tracking=false
- 発生条件
- 実装evidence

Privacy Policy URL / User Privacy Choices URL / tracking / required-reason APIも同じ正本へ含める。

### `APP_STORE_METADATA_JA.md`

- User Privacy Choices URLを正本化。
- 8 data typeのApp Store入力表を追加。
- `Photos or Videos` とPhotos library permissionが別概念であることを明記。
- 最終転記正本を `APP_STORE_PRIVACY_RESPONSES.json` に一本化。
- W01統合後の審査前auth gateにconfirmation callbackとpassword recovery callbackの両方を追加。

### `APP_REVIEW_NOTES_JA.md`

- generated `preview.jpg` の送信・削除・App Privacy申告を明記。
- Privacy Manifest/App Store回答を8種へ更新。
- User Privacy Choices URLを追加。
- W01統合後に両callback URL、メールredirect/PKCE、実メール復帰を確認するgateを追加。

### `privacy.html`

- `preview.jpg` はユーザー3Dからアプリ内生成した画像であることを説明。
- Photos libraryから取得した画像ではなくPhotos permissionを要求しないことを明記。
- Supabase保存・retention・scan/account deletionにpreview画像を含めた。
- privacy choicesページへの導線を追加。

### `privacy-choices.html`

App Store ConnectのUser Privacy Choices URL用ページを新設。

- Location permission撤回
- 既送信location削除
- unpublish
- scan delete
- account + cloud data delete
- support fallback

を1ページに集約した。

### `scripts/test_d2_privacy_contract.py`

回帰gateを次のように強化。

- Manifestは8 data typesの完全一致を要求。
- `Photos or Videos` を必須化。
- `ScanModel -> ScanLabShellView -> trusted publish preview.jpg` の実装経路を静的確認。
- `APP_STORE_PRIVACY_RESPONSES.json` のdata typesがManifestと集合として完全一致することを確認。
- 8種すべてPurpose / Linked / Tracking回答を検査。
- Privacy Policy URL / User Privacy Choices URLを検査。
- privacy choicesページが具体的な撤回・削除導線を持つことを検査。
- W01 password recovery integration gateが審査文書に保持されることを検査。

## Harsh review

### `Photos or Videos` を追加しない案 — 却下

previewは3Dの派生物なので `Other User Content` / `Environment Scanning` だけで表現できるという解釈は可能だが、実際にはJPEGという具体的なmedia typeとしてオフデバイス保存される。AppleのApp Privacy Detailsは特定media typeをアップロードする機能では具体的なtypeを開示する方向なので、過少申告リスクを避けるため別途 `Photos or Videos` を申告する。

### Photos permissionを追加する案 — 却下

App Privacy data typeとOS権限は別契約。previewはPhotos libraryから取得せず、trainer renderから生成するためPhotos permissionは不要。権限を増やすと実挙動と不一致になる。

### Markdown表だけを正本にする案 — 却下

人間向け表だけではManifest追加時にApp Store回答を更新し忘れる。JSON正本を追加し、Manifestと8種が完全一致しなければCI FAILとする。

### `privacy.html` をUser Privacy Choices URLにも兼用する案 — 却下

Privacy Policyは説明文が中心で、利用者の変更・削除操作だけを探すには長い。App Storeの任意欄を実用的に使うため、self-serviceの選択肢を短く集約した専用ページを採用した。

## Remaining external / integration gates

- W09成果を統合後、Privacy Policy / User Privacy Choices / Supportの3 URLをGitHub Pages上でHTTPS実到達確認する。
- App Store Connect実画面へ `APP_STORE_PRIVACY_RESPONSES.json` の8 data typesを転記し、保存後のPrivacy Nutrition Labelを最終統合buildと再突合する。
- W01統合後、Supabase Auth allow-listにconfirmation/recovery両callbackを設定し、実メールE2EをPASSさせる。
- W03/W05/W06/W08統合後、公開・Map・Discover・block/rate-limitの最終挙動とprivacy文言を再突合する。
- 本審査への自動提出は禁止したままとする。
