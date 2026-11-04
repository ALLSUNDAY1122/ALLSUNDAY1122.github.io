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

## 2026-11-04｜PDL1.0出典・加工表示の実装

厚生労働省の公式利用条件（https://www.mhlw.go.jp/chosakuken/）では、特記のないコンテンツはPDL1.0に準拠し、出典URLと、編集・加工した場合の加工表示が必要とされる。利用条件の適用除外一覧（https://www.mhlw.go.jp/chosakuken/exhibit.html）に薬剤師国家試験問題PDFは列挙されていないことを確認した。ただし、個別の権利表示がある素材や第三者権利のある素材は別途確認する。

TestFlight候補では、全1,035問について次を実装する。
- 問題表示画面に厚生労働省の出典名と、問題ごとの公式PDF URLを回答前から表示する。
- 加工表示を「加工：学びスプリント開発者。厚生労働省公開問題をもとに、学習用に表示形式を整え、解説を付加。」とする。
- 解説詳細に、問題ごとの公式出典URLを再掲する。
- 正誤表訂正対象には公式正誤表URLを表示する。
- 法令・基準に時点差がある設問には、関連する公的原典URLを表示する。

第三者由来4問（P109-025、P109-124、P110-122、P110-140）は元図表を転載せず独立した文章問題へ再構成した。ただし、数値・事実の原典照合と出典表示は個別レビューキューで継続する。特にP110-122は学術論文由来の数値を利用しているため、原表・原文を転載していないことを再確認する。

Q0の法令・権利確認全体が完了したという意味ではない。今回の修正は、既知の出典表示欠落と、確認済みの時点差・正誤表未反映を修正するものであり、全107件の法令確認および画像154問の最終視覚監査は継続する。
