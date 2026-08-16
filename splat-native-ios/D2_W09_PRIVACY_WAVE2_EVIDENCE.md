# D2-009 Privacy / App Review Wave 2 Evidence

- Date: 2026-08-16
- Worker: D2-009
- Branch: `scaniverse/d2-w09-privacy`
- Parent HEAD: `aa69f94f6fc81eff4b010b6c0857abf203ae1c76`
- Base checked at Wave start: `scaniverse/d2-share-discover` = `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
- Scope: Privacy Manifest / App Review説明 / 権限文言 / D2公開機能privacy整合 / D2回帰gate

## Canonical refresh

Wave開始時にNotion「Scaniverse同等化｜4開発班＋統合本部 v2.0」、統合PR #4145、D2 base、D2-009 branchを再取得した。前WaveのPrivacy Manifest / upload / location / App Privacy整合は再実装しない。

同時に他D2 Workerのbase差分を確認した。
- w01 auth/profile: ahead 1
- w03 visibility: ahead 1
- w05 Map/geo: ahead 1
- w06 Discover: ahead 1
- w07 owner lifecycle: baseとidentical
- w08 safety: ahead 1

他Worker branchは変更していない。

## Largest unfinished privacy/review delta

Appleの現行App Review要件とD2実装を突合した結果、UGCの報告・ブロックに加えて、利用者が開発者へ容易に到達できる公開連絡先の契約が弱かった。

実装では `ScanLabAccountView.swift` に「サポート・お問い合わせ」があり、`ScanLabConfig.supportURL` は `https://allsunday1122.github.io/splat-native-ios/support.html` を指していた。しかし公開 `support.html` は旧名称「Splat Lab」のままで、問い合わせ方法はGitHub Issuesのみ。アカウント削除、privacy、不適切コンテンツの連絡窓口としてApp Review説明・App Store入力正本と固定されていなかった。

## Fix

- `support.html`
  - user-facing名称を `Scan Lab` に統一。
  - 公開メール問い合わせ先を追加。
  - UGCの報告・ブロック、アカウント/クラウド削除、privacy問い合わせの導線を明示。
  - privacy policyへの相互リンクを維持。
- `privacy.html`
  - お問い合わせ節を追加。
  - Support pageと公開メール窓口、アプリ内report/block導線を明示。
- `APP_REVIEW_NOTES_JA.md`
  - Support URL / Privacy Policy URL / 公開問い合わせ先を明示。
  - ログイン前後のAccount画面からsupportへ到達できる審査手順を追加。
  - UGC safetyとaccount deletionで共有UGCを削除対象とする説明を強化。
- `APP_STORE_METADATA_JA.md`
  - App Store Connect入力正本へSupport URL / Privacy Policy URL / 公開問い合わせ先を追加。
  - 本審査前に公開URLのHTTPS到達性と最終build一致を実確認するgateを追加。
- `scripts/test_d2_privacy_contract.py`
  - `ScanLabConfig.supportURL`、Account画面support/privacy link、公開support page、メール窓口、UGC safety、App Store URL申告を回帰contractへ追加。
  - user-facing support pageへ旧 `Splat Lab` 名称が復活した場合はFAILする。

## Harsh review

単にApp Review Notesへ「連絡先あり」と追記する案は不採用。審査説明だけが正しくても、実際の公開ページが旧名称・不十分な窓口なら審査時に破綻するため、アプリ内リンク先・公開ページ・privacy policy・App Store入力正本を同一contractで固定した。

GitHub Issuesだけを唯一の問い合わせ先として残す案も不採用。公開メール窓口を併設し、アカウントやprivacy、UGC安全の問い合わせをGitHubアカウントの有無に依存させない。

## Regression gate

既存CIの `python3 splat-native-ios/scripts/test_d2_privacy_contract.py` を拡張する。新規workflowは作らない。

検査対象:
- Privacy Manifest / Required Reason API
- explicit location / explicit trusted upload
- auth / UGC actions / deletion contract
- Account画面のsupport/privacy link
- Support URLの実装定数
- 公開support pageの問い合わせ・UGC・削除説明
- privacy policyからsupportへの導線
- App Review / App Store metadataの公開URLと問い合わせ先

## Remaining external gate

feature branch自体はGitHub Pagesの本番公開面ではないため、公開URLの実HTTP到達性は統合・Pages反映後に最終確認する。本WaveではApp Store本審査提出やApp Store Connect本番入力は行わない。
