# ChatGPT primary development state｜危険物乙4

更新: 2026-08-10

## 担当
本アプリはCodexへ移管せず、ChatGPT内でSwiftUIネイティブ実装・検証・Release Gate・Internal TestFlight準備を継続する。

過去の `CODEX_HANDOFF_20260809.md` / `CODEX_READ_FIRST_20260810.md` は履歴としてのみ残し、現在の担当指示として使用しない。

## 最上位識別情報
- Apple Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.otsu4`
- App Store Connect App ID: `6799755566`
- Codemagic provisioning profile: `otsu4_appstore`
- IAP: `jp.allsunday1122.otsu4.premium`
- Version: `1.0.0`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査への自動提出は禁止

## 実装済み
- SwiftUI native
- 標準8問 / 4・8・16問
- ホーム / 模試 / 記録 / 設定
- 即時採点 / わからない
- 苦手登録 / 3連続正解解除
- 中断復帰
- 履歴 / 5週間ヒートマップ
- JSON backup / restore
- 360問オフライン問題バンク
- 模試3回・35問・120分・3科目60%判定
- StoreKit 2 non-consumable / restore
- revocation / pending / cancelled / unverifiedで誤解放しない

## 2026-08-10追加品質ゲート
- Unit XCTest target
- UI XCTest target
- 苦手ロジックテスト
- JSONバックアップ往復テスト
- 模試タイマー復元テスト
- 科目別60%合否テスト
- 4タブ / わからないUI smoke test
- VoiceOver label空欄検査
- 横方向はみ出し検査
- 小型 / 大型 iPhone Simulatorテスト

## Release blocker
1. App Icon
   - Google Drive正本: `01_危険物取扱者_乙種4類.png`
   - file ID: `10B_svZxlg80KfV61atBj4_sBkMTndFwS`
   - SHA-256: `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d`
   - 現在の生成アイコンを完成扱いしない。正本PNGを同一SHAでAsset Catalogへ固定するまでTestFlight禁止。
2. Codemagic signing certificate
   - profile referenceは `otsu4_appstore` に固定済み。
   - 対応Apple Distribution証明書のReference nameは正本未記載。推測禁止。
   - 署名付きIPA前にCodemagic上の実在設定が必要。
3. XCTest再監査
   - コード変更により旧Release Gate PASSは失効。最新headですべて再PASSするまでRelease Gate未完了。

## STOP
- App Store本審査へ送らない
- PR #4069はInternal TestFlight実機確認完了までDraft
- Bundle ID / App ID / IAP / profile / 資格名を変更しない
- 未記載値を推測しない
