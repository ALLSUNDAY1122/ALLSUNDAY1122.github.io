# App Privacy / Content Rights｜薬剤師国家試験｜学びスプリント

## App Privacy実装正本
- Developer data collection：なし
- Tracking：なし
- Advertising：なし
- Analytics SDK：なし
- Account / login：なし
- Independent cloud sync：なし
- 学習履歴：端末内のみ
- アプリ内課金：なし。現行XcodeターゲットにStoreKit課金・購入復元・権利制限は含めない。
- Privacy Manifest：`NSPrivacyTracking=false` / `NSPrivacyCollectedDataTypes=[]` / `NSPrivacyAccessedAPITypes=[]`

実装変更で収集・追跡・Required Reason API利用が増えた場合はPrivacy監査を再発火し、この申告を先に更新する。

## Content Rights
- 対象：厚生労働省 第111・110・109回薬剤師国家試験
- 収録レコード：1,035
- 通常採点対象：1,031
- 公式「解なし」：4問（通常採点から除外）
- 構造検証：`content/product/final-audit-v2.json` のPASSは件数・必須項目等の機械検証に限る。医学・薬学内容、画像目視、法令時点、権利の監査完了を意味しない。
- 公開判定：BLOCKED。`content/source-manifest.json` の `fullProblemAuditComplete` はfalse。
- generated supplement：0
- unresolved high similarity：0
- 第三者由来が確認された図表4問：原図を使わず文章問題へ再構成。ただし権利監査キューはALL_PENDINGであり、許諾・適合確認済みとは扱わない。
- 公式問題画像154問：出典・加工表示を問題単位で保持。全154問の最終目視監査は未完了。
- 法令関連107候補：個別の試験時点・現行基準の照合が未完了。候補数は確定欠陥数ではない。
- アプリ内・Supportに「厚生労働省公式アプリではない」と明示

App Store ConnectのContent Rights質問には、実際の収録方法と厚生労働省の利用条件、第三者素材の再構成処理に基づいて回答する。権利不明の素材を推測で「許諾済み」と扱わない。
