# 課金導入後・辛口レビュー再監査｜保健師国家試験｜学びスプリント

基準日: 2026-08-14
対象: SwiftUI Native / StoreKit 2 / 無料30問・Premium300問 / GitHub Pages公開Support・Privacy

## 第1周｜無料体験と課金境界

### 指摘
- 無料30問が10分野に偏らず配置されているかを明示的に固定する必要がある。
- 科目別学習で無料3問しかない場合、目標8問に合わせるため同じ問題を反復してはいけない。
- 模試はPremium専用であることを押下時にも一貫して扱う必要がある。

### 対応
- release gateで free=30 / premium=300 / 無料10分野×3問を固定。
- `LearningEngine.selectSprint` は利用可能問題数がtarget以下なら、その集合をそのまま返し重複補充しない。
- 10科目すべてについて、無料科目別は3件・全ID一意、Premium科目別8問は8件・全ID一意を `testSubjectSprintNeverRepeatsQuestionsToFillTarget` で固定。
- 模試は未購入時にPaywallへ遷移し、購入済みのみ開始。

### 判定
PASS。公開Safari試作品で見られた「代表1問を8回繰り返す」挙動は本番Nativeへ持ち込まない。

## 第2周｜購入失敗・復元・通信不良

### 指摘
- StoreKit製品情報の初回取得に失敗した場合、価格未取得のまま購入ボタンを押しても同じエラーになるだけで回復導線が弱い。
- 購入済み権利の復元は常設する必要がある。
- 未検証transactionやrevocation済みtransactionで解放してはいけない。

### 対応
- 製品情報未取得時は購入ボタンを無効化し、「製品情報を再読み込み」を表示。
- 「購入を復元」を常設し `AppStore.sync()` 後にcurrent entitlementsを再監査。
- verified / productID一致 / revocationなし / isUpgraded=false のみPremium解放。
- transaction updatesを監視し、失効時はPremiumを解除。
- 表示価格は `Product.displayPrice` のみ使用。

### 判定
PASS。実App Store製品を使った購入・復元の最終確認はInternal TestFlightで行う。

## 第3周｜説明・プライバシー・サポート

### 指摘
- Privacy原稿が課金導入前の「将来導入する場合」のままだと実装と不一致。
- Supportに購入復元の案内と問い合わせ経路が必要。
- 課金が買い切りであることと、無料範囲を誤認させない必要がある。

### 対応
- Privacyを現行StoreKit買い切りPremiumに更新。
- Supportへ購入復元FAQ、機密情報を送らない注意、GitHub Issues問い合わせ導線を追加。
- Privacy / SupportをGitHub Pages mainへ先行公開。
- Paywallで「買い切り。定期購読ではありません」「無料30問」を明示。

### 判定
PASS。

## 残件
- Apple Developer / App Store Connect上でBundle IDと新規Appレコードを作成し、Apple発行の数値App IDを取得する。
- 非消耗型IAP `jp.allsunday1122.hokenshi.premium` をApp Store Connectに作成する。
- Google Drive正本AppIcon `13_保健師国家試験.png` の実バイトを署名ビルド環境へ搬送し、SHA-256 `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64` を確認する。Driveファイルの公開権限は変更しない。
- Codemagic signed IPA → Internal TestFlight。
- 次の人間確認地点は #3 Internal TestFlight実機確認。本審査は #4 明示承認まで行わない。
