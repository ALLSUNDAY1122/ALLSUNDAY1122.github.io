# App Privacy / Content Rights｜薬剤師国家試験｜学びスプリント

## App Privacy実装正本
- Developer data collection：なし
- Tracking：なし
- Advertising：なし
- Analytics SDK：なし
- Account / login：なし
- Independent cloud sync：なし
- 学習履歴：端末内のみ
- StoreKit：Appleが決済処理。本アプリは商品情報・購入権利の状態のみ利用し、カード情報を取得しない
- Privacy Manifest：`NSPrivacyTracking=false` / `NSPrivacyCollectedDataTypes=[]` / `NSPrivacyAccessedAPITypes=[]`

実装変更で収集・追跡・Required Reason API利用が増えた場合はPrivacy監査を再発火し、この申告を先に更新する。

## Content Rights
- 対象：厚生労働省 第111・110・109回薬剤師国家試験
- 収録レコード：1,035
- 通常採点対象：1,031
- 公式「解なし」：4問（通常採点から除外）
- 問題監査：`content/product/final-audit-v2.json` = PASS
- generated supplement：0
- unresolved high similarity：0
- 第三者由来が確認された図表4問：原図を使わず独立した文章問題へ再構成
- 公式問題画像154問：出典・加工表示を問題単位で保持
- アプリ内・Supportに「厚生労働省公式アプリではない」と明示

App Store ConnectのContent Rights質問には、実際の収録方法と厚生労働省の利用条件、第三者素材の再構成処理に基づいて回答する。権利不明の素材を推測で「許諾済み」と扱わない。
