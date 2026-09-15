# 開発連番#15 理学療法士国家試験｜学びスプリント 最終辛口レビュー

実施日: 2026-08-14
対象: `feat/15-rigaku-sprint-native` / Draft PR #4139
基準: 学びスプリント標準手順 v2.2 / UI Golden Master v2.1 / 問題生成・監査ループ v1.0 / 申請手順

## Round 1 — 問題・医学内容・権利

### 指摘
1. 600という件数だけが揃っても、番号と論点がずれた問題を検出できない。
2. 別回に同文・高類似問題があれば水増しに見える。
3. `sourceRefs` がPubMed検索結果ページでは最終根拠として弱い。
4. 公式図版依存問題をそのまま「公式過去問」と見せると権利・表示の両面で不適切。
5. 公式採点除外・複数正答の履歴を独自問題の正答へ混ぜると、模試得点が公式配点とずれる。

### 改善
- 第58回午前21〜40の論点ずれ20問を全再作問。
- 600問すべてで分類台帳のsubject/topic一致をCI必須化。
- 600問ちょうど、各回200、各AM/PM100をCI必須化。
- 完全重複・高類似をCIでFAIL。検出5組は別角度の独立問題へ再構成。
- 検索結果URLを最終根拠として禁止。検出7問を特定論文・ガイドラインへ固定。
- 66枠の第三者権利未解決図版を収録せず、文章問題へ独自再構成。
- 公式採点調整20件（除外6、複数正答14）を別台帳で保持。
- 採点除外枠は独自参考問題として表示可能だが模試0点を維持。
- 第59回は訂正後公式正答を正本化。

### 判定
PASS。600/600問題、内容監査600/600、各回200、各AM/PM100、重複・高類似0、検索結果ページ根拠0を高速品質ゲートで検証する。

## Round 2 — UI・学習導線・誤認防止

### 指摘
1. 「第○回模試」「本番形式」という表示は、図版・問題文を独自再構成している実態より強い。
2. 現行入口はV2なのに旧Root実装が残り、将来誤って修正される危険がある。
3. Privacy PolicyがWebにあってもアプリ内から到達できなければ申請上弱い。
4. StoreKit2基盤が共通コアにあるだけで#15の設定画面へ接続されていない。

### 改善
- 表示を「第58〜60回ベース模試」「第○回ベース模試」へ変更。
- 公式出題枠・配点を基準にしつつ、問題文・図版は権利・内容監査した独自問題で再構成した旨を模試画面と結果画面に明記。
- 旧 `RigakuRootTabView.swift` を削除。静的監査で旧Rootの再混入を禁止。
- SettingsへSupport / Privacy Policy / TermsのリンクSectionを追加。
- Product IDが正本設定された場合のみ表示されるStoreKit2購入・復元Sectionを用意。
- 価格はStoreKit `Product.displayPrice` のみを表示し、価格文字列をハードコードしない。
- Product ID未確定時はStoreKitを起動せず、未展開 `$(...)` 値も無効扱い。

### 判定
PASS（製品UI）。ただしIAPの実際の商品種別・価格・無料/有料範囲はプロダクト判断のため未決定で、リリースpreflight上のHuman Decisionに分離。

## Round 3 — Privacy・StoreKit・申請資産・ビルド

### 指摘
1. Privacy Manifestを空想で作ると、実装との不一致が申請リスクになる。
2. Bundle ID / App Store Connect Apple ID / IAP Product IDを推測すると署名・審査事故になる。
3. 学びスプリント正本AppIconを再生成・加工してはいけない。
4. CIがPASSしても、AppIcon本体や公開Support URL等が未完成ならTestFlight/App Storeへは進めない。
5. PR本文が古く、600問未収録と誤記したまま。

### 改善
- `PrivacyInfo.xcprivacy` を実装に合わせて追加。現行版はtracking=false、開発者収集データ0、Required Reason API宣言0。
- `privacy_audit.py` でRequired Reason API候補、ネットワーク/追跡API、manifest整合を監査。
- Bundle IDは `RIGAKU_BUNDLE_ID`、IAP Product IDは `RIGAKU_IAP_PRODUCT_ID` の外部注入に限定。
- StoreKit2はverified transaction、未取消、対象Product ID一致のみpremium権利へ反映。
- Support / Privacy / Terms HTMLを作成。main統合後に公開確認する。
- App Storeメタデータ案を作成し、未確定識別子・課金条件は明示的に空欄とした。
- `release-canonical.json` と `release_preflight.py` を追加し、Internal TestFlightとApp Store提出のブロッカーを別判定にした。
- AppIcon正本はDriveの `15_理学療法士国家試験.png`（1024×1024、663589 bytes、SHA-256 `5ffc2de874d6f22b0fd6ee121e7c691ae7a7caee30844fad059439846dfefca9`）と特定済み。
- GitHubコネクタがバイナリ直接投入を持たず、Driveの匿名DLも中間レスポンスとなるため、正本PNG本体だけは未投入。Asset Catalogのslotだけ準備し、PNG未投入中はAppIcon compiler設定を有効化しない。

### 判定
製品コード/監査: PASS待ち（最終macOS Native iOS Quality Gateで確定）。
Internal TestFlight preflight: BLOCKED。理由は正本AppIcon本体未投入、App Store Connect Apple ID未確定、Bundle ID未確定。
App Store preflight: BLOCKED。上記に加えSKU、Copyright owner、Support問い合わせ先の公開承認、課金方針、最終提出承認が必要。

## 人間判断として残すもの

### Internal TestFlight前
- App Store Connect Apple ID
- Bundle ID
- Drive正本AppIcon PNGのGitHub Asset Catalogへの投入（正本バイナリそのもの。再生成禁止）

### 課金を採用する場合
- 課金方針: IAPあり / なし
- IAPありの場合: 商品種別、Product ID、価格方針、無料/有料範囲

### App Store提出前
- SKU
- Copyright owner
- 公開してよいサポート問い合わせ先
- Support/Privacy/Termsのmain公開確認
- TestFlight実機確認
- 最終提出承認

上記以外は人間判断として残さない。
