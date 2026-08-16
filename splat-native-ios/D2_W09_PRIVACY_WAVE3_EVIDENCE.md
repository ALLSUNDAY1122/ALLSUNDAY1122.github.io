# D2-009 Privacy Wave 3 Evidence

- Date: 2026-08-16 JST
- Worker: D2-009
- Branch: `scaniverse/d2-w09-privacy`
- Base: `scaniverse/d2-share-discover`
- Wave start worker HEAD: `3e080cbb86ef748f3dacd7662ed35b4e19cfcb2c`
- Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
- Scope: Privacy Policy retention/deletion/consent/third-party protection + App Review alignment

## Canonical refresh

Wave開始時にNotion「Scaniverse同等化｜4開発班＋統合本部 v2.0」、GitHub統合PR #4145、D2 base、D2-W09 branchを再取得した。D2 baseは前Waveから不変で、W09も前Wave完了HEADのままだった。完了済みのPrivacy Manifest data-type追加、UGC support contact、公開URL申告は再実装していない。

並行D2 Workerも確認した。D2-W01はメール確認callbackを追加しているが、production Supabase Auth redirect allow-listと実メール確認E2Eは未完了として証拠化されている。D2-W08は双方向block enforcementとpersonalized API no-storeを追加している。これらのbranchは変更していない。

## Apple primary-source audit

2026-08-16時点のApple Developer一次資料を再確認した。

- App Review Guideline 5.1.1(i): Privacy Policyは収集データ・取得方法・全用途に加え、データへアクセスする第三者が同等の保護を提供すること、data retention/deletion policy、同意撤回または削除要求方法を明示する必要がある。
- Guideline 1.2 / 1.5: UGCにはfilter/report/block/published contact informationが必要で、Support URLにも容易な連絡手段が必要。これはWave 2で対応済み。
- Apple privacy manifest data type docs: `NSPrivacyCollectedDataTypeEnvironmentScanning` と `NSPrivacyCollectedDataTypeProductInteraction` は現行の正式値。
- Required Reason API docs: app container内ファイルのtimestamp/size/metadataアクセスにはFile Timestamp categoryの `C617.1` が現行理由として有効。
- Account deletion guidance: 共有UGCもaccount deletion対象に含める必要がある。既存D2 delete-accountはStorage asset削除→auth user削除、DBはcascade契約を持つ。

## Largest remaining gap

Wave 2後の `privacy.html` は収集内容、Supabase利用、公開範囲、削除導線、問い合わせを説明していたが、Guideline 5.1.1(i)が要求する次の3点が明示不足だった。

1. Supabase等、ユーザーデータへアクセスする第三者サービスに要求する保護水準。
2. データをどの条件・期間保持するかというretention policy。
3. 位置情報・公開・クラウド利用について、利用者が同意を撤回し既送信データを削除する具体手順。

## Fix

### `privacy.html`

- 「第三者サービスとデータ保護」を追加。
- Supabaseへ送信・保存されるデータ範囲を明示。
- 第三者サービスは本ポリシーおよび適用Apple要件と同等以上の保護を行うものに限定するpolicyを明記。
- 広告目的での販売・tracking提供を行わないことを明記。
- 「保存期間と削除」を追加し、アカウント/対象データが存在し機能提供・安全運用に必要な間保持するlifecycle基準を明記。
- scan delete / account deleteで何が削除対象になるかを実装と一致させた。
- 法令または正当なsecurity obligationがある場合は必要範囲・期間に限定することを明記。
- 「同意の撤回と設定変更」を追加。
- iOS SettingsでLocation permissionを撤回できること、既送信locationはscan削除で削除すること、公開停止/個別削除/account削除の使い分けを明記。

### `APP_REVIEW_NOTES_JA.md`

- 保存期間・削除・同意撤回をReviewer向けに要約。
- Supabaseのthird-party protection contractを追加。
- Internal TestFlight確認手順にLocation permission撤回を追加。
- D2-W01 callback統合後も、Supabase Auth URL Configuration / confirmation redirect / 実メール確認→app復帰→session成立が未検証ならsignupを審査完成扱いしないgateを追加。

### `APP_STORE_METADATA_JA.md`

- App Privacy正本にthird-party / retention / consent withdrawalを追加。
- Auth callback統合時のproduction redirect実確認を審査前gateとして追加。

### `scripts/test_d2_privacy_contract.py`

- 5.1.1(i)の3要件がprivacy policyから欠落するとFAILする静的gateへ拡張。
- App Review / App Store metadataにも同じ契約が存在することを固定。
- Wave 2のPrivacy Manifest / Required Reason API / support / UGC / explicit upload checksは維持。

## Harsh review

固定日数（例: 30日・90日）のretentionを新たに宣言する案は却下した。現在のbackendにはその日数で自動purgeする仕組みがないため、文書だけの期限を設定すると虚偽申告になる。実装に一致するlifecycle-based retention（アカウント/対象データが存在し必要な間）を採用し、削除操作による終了条件を明確化した。

「Supabaseが必ず同等以上の保護を保証する」と外部事業者の事実を断定する表現も避けた。Scan Lab側の利用policyとして、ユーザーデータへアクセスする第三者サービスを同等以上の保護を行うものに限定する、と記述した。

D2-W01の未統合callbackコードをW09 privacy gateから直接requireする案も却下した。専門branch分離を壊し、W09単独CIを他Worker実装へ依存させるため。代わりにApp Reviewのintegration gateとして記録した。

## Remaining external/integration gates

- GitHub Pagesへ統合後、Support / Privacy URLのHTTPS到達を実確認する。
- App Store ConnectのPrivacy Nutrition Labelを最終統合buildと突合する。
- D2-W01統合後、Supabase Auth redirect allow-list / email template redirect / real email confirmation callback E2Eを確認する。
- D2-W08のblock/moderation変更が統合された時点で、公開policy文言とApp Review手順を再突合する。
- App Store本審査への自動提出は行わない。
