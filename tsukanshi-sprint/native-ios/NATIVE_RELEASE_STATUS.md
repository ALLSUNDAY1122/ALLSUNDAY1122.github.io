# 通関士｜学びスプリント Native Release Status

更新日: 2026-08-10

## 現在地
純SwiftUIネイティブ移行の実装済み。Release Gate検証中。

## 固定識別子
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Codemagic profile: `tsukanshi_appstore`
- Product ID: `jp.allsunday1122.tsukanshi.premium`
- Team ID: `MN3D2ZM44N`
- Version: `1.0.0`

## 実装済み
- WKWebViewを主UIから完全除去
- ホーム／模試／記録／設定
- 4／8／16問、既定8問
- singleChoice / multiChoice / numeric / blankSelect / declaration
- `わからない`正式回答
- 苦手登録、3連続正解で解除
- 中断・再開
- 学習履歴、科目別正答率、5週間ヒートマップ
- 科目・模試・実務演習の完答回数
- 計算／申告書演習の専用導線
- JSONバックアップ／復元
- StoreKit 2 非消耗型、`Product.displayPrice`、購入復元
- verified entitlementのみ解放。pending/cancel/unverified/revocationで新規解放しない
- 監査済み480学習問＋申告書12セットをビルド時JSONへ変換
- `contentVersion` / `lawBaselineDate` / `sourceCheckedAt` / 権利根拠を保持
- 旧19問は既存一次資料カタログへの明示対応表を使用し、日付・URLを推測しない
- 公式過去問本文は同梱せず、税関公式ページを外部リンクで開く

## 監査で見つけて修正済み
1. JSONバックアップの小数秒欠落 → fractional ISO-8601へ変更。
2. 模試の複数選択・空欄で途中回答が保存され得る → 完全回答時のみ保存。
3. 最終問題を`わからない`で終えると模試採点を通らない → `finishMock`へ統一。
4. 申告書の許容別名をnative変換で失う → aliasesを共通モデルへ追加。
5. 数値の`roundingRule`を推測する余地 → 未構造化はnull＋監査警告として保持。
6. 科目／試験回カードの完答回数不足 →永続completion ledger追加。
7. 通関実務の計算／申告書専用導線不足 → 模試タブへ追加。
8. StoreKit通信失敗で既存verified権利まで落とす可能性 → currentEntitlements再評価で保持。

## テスト
- Linux Fast Preflight: 480＋12監査、権利・出典メタデータ、WebKit参照0、全Swift構文parseをPASS済み。
- macOS Full Gate: XcodeGen、Release build、XCTest、小型／大型iPhone UI testを実行してPASS確認するまで未完了。

## Release blocker
- macOS Full Gate未完了。
- Google Drive正本 `02_通関士.png` の1024px原本を、SHA-256固定でrelease assetへ搬送する工程未完了。仮アイコンは禁止。
- root `codemagic.yaml` は旧WKWebView targetのまま。Full Gateと正本アイコン完了後にnative project＋profile `tsukanshi_appstore`へ切り替える。
- signed IPA / App Store Connect upload / Internal TestFlight / iPhone実機Sandbox購入・復元は未実施。

App Store本審査への自動提出は禁止。
