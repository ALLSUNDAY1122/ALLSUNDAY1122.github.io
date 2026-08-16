# D2-009 Privacy Alignment Evidence

- Date: 2026-08-16
- Worker: D2-009
- Branch: `scaniverse/d2-w09-privacy`
- Base: `scaniverse/d2-share-discover`
- Base SHA at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
- Scope: Privacy Manifest / App Review説明 / 権限文言 / D2公開機能のprivacy整合 / D2回帰gate

## Canonical unfinished delta

Notion「Scaniverse同等化｜4開発班＋統合本部 v2.0」と統合PR #4145をWave開始時に再取得し、D2の未完了gateとしてPrivacy Manifest / App Review説明の最終整合を確認した。

## Before: detected mismatches

1. `privacy.html` は旧ローカル版の説明のままで、外部API・アカウント・位置情報・開発者収集が無いと記載していた。
2. `APP_REVIEW_NOTES_JA.md` / `APP_STORE_METADATA_JA.md` も、ログインなし・位置情報なし・外部APIなしという旧説明だった。
3. 実装は既にSupabase Auth / Database / Storage / Edge Functionsを使用し、メール、プロフィール、公開3D、public時の明示位置情報、いいね・報告・ブロック等をサーバー側で扱っていた。
4. `PrivacyInfo.xcprivacy` はName / Email Address / User ID / Precise Location / Other User Contentを申告済みだったが、共有3Dに対応するEnvironment Scanning、サーバー保存されるコミュニティ操作に対応するProduct Interaction、ファイルmetadata確認に対するRequired Reason API申告が欠けていた。

## Runtime evidence used for alignment

### Explicit location opt-in

`PublishScanView.swift` は位置情報を自動取得しない。`public` 選択時に利用者が「現在地を公開地点に設定」を押した場合だけ`requestWhenInUseAuthorization()` / `requestLocation()`へ進み、取得後も「投稿するまで送信されません」と表示する。`unlisted` / `private` へ切り替えると位置情報を外す。

### Explicit trusted upload

現在の公開UIは `publishTrustedPackage(...)` を使用する。`ScanLabBackend+TrustedPublish.swift` はローカル生成結果から `scene.spz` + `manifest.json` + optional previewを作成して明示アップロードし、raw reconstruction `.splat` は公開UI経路から送信しない。

### Account / community / deletion

`ScanLabBackend.swift` はメール認証、プロフィール、like、report、block、scan削除、account削除を実装している。`scanlab-delete-account` Edge Functionは所有者のStorage assetを削除した後に認証ユーザーを削除する。関連テーブルはauth userへの`ON DELETE CASCADE`を持つ。

## Fix applied in this Wave

- `SplatNative/PrivacyInfo.xcprivacy`
  - Tracking=false維持。
  - Name / Email Address / User ID / Precise Location / Other User Content維持。
  - Environment Scanning追加。
  - Product Interaction追加。
  - File Timestamp category + `C617.1`追加。
- `privacy.html`
  - D2の実アカウント、明示cloud upload、public/unlisted/private、位置情報opt-in、UGC操作、削除を実装と一致させた。
- `APP_REVIEW_NOTES_JA.md`
  - 実authを含む審査導線、権限、送信データ、公開範囲、安全機能、削除手順、Internal TestFlight確認手順へ更新した。
- `APP_STORE_METADATA_JA.md`
  - App Store Connect入力正本をD2実装へ更新し、App Privacy申告項目を明示した。
- `scripts/test_d2_privacy_contract.py`
  - 実装・権限文言・Manifest・公開policy・App Review説明の相互整合を静的に検査する回帰gateを追加した。
- `.github/workflows/splat-native-ios.yml`
  - 既存のSplat Native iOS CIにprivacy alignment gateを1 step追加した。新しいworkflowは増やしていない。

## Regression gate

CI / local command:

```bash
python3 splat-native-ios/scripts/test_d2_privacy_contract.py
```

Gateが検査する主項目:

- 位置情報permission文言がexplicit opt-inであること。
- 公開UIがlegacy raw `.splat` publishを呼ばずtrusted packageを使用すること。
- D2 account / like / report / block / delete実装が存在すること。
- Privacy Manifestが7データ種別、Tracking=false、FileTimestamp `C617.1`を持つこと。
- privacy / App Review / App Store metadataの3文書がSupabase、`scene.spz`、`manifest.json`、public/unlisted/privateを説明すること。
- 旧「アカウントなし・外部APIなし・位置情報なし・収集なし」文言が復活していないこと。

## Harsh review outcome

文書だけ直す案は不採用とした。理由は、D2の実装変更後に説明文だけ再び古くなっても検知できないため。実装→Manifest→権限文言→公開policy→App Review正本の契約を自動gateで固定した。

また、Privacy Manifestを既存5種のままにする案も不採用とした。公開3Dは周囲環境を表す派生データとしてサーバーへ送信され、like/report/blockはユーザー操作としてサーバー保存されるため、保守的にEnvironment Scanning / Product Interactionを申告する方が実挙動との不一致リスクが低い。

## External / human gate remaining

このWaveではApp Store Connect本番画面への入力やApp Store本審査提出は実行していない。最終buildでApp Store ConnectのPrivacy Nutrition Label、審査用アカウント、公開プライバシーポリシーURLを再突合する必要がある。本審査への自動提出禁止は維持する。
