# IAP Review Screenshot

旧「買い切りのみ」の審査画像候補は使用しない。

ASC設定済み:
- 月額商品: `jp.allsunday1122.healthmanager1.monthly` / JPY 200 / JPN availability=true
- Introductory Offer: `FREE_TRIAL / ONE_WEEK / 1 period` / JPN / 2026-08-23開始 / read-back PASS
- 買い切り商品: `jp.allsunday1122.healthmanager1.lifetime` / JPY 800 / JPN availability=true
- Internal TestFlight: Version 1.0.0 / Build 2026081903 / group `sun`

実機で残る確認:
1. TestFlight Build `2026081903` を起動し、白画面・クラッシュがないこと。
2. 課金画面でStoreKit実値として「月額200円」「買い切り800円」が表示されること。
3. Introductory Offer対象アカウントでは7日間無料が表示されること。
4. 購入と「購入を復元」を実行し、再起動後も権利状態が正しいこと。
5. 264問・スプリント・セット選択の主要導線を確認すること。
6. 上記の正式価格と購入選択肢が同一画面で確認できる課金画面をApp Review用スクリーンショットとして撮影すること。

App Review用画像は実際のTestFlight課金画面から取得する。生成画像・旧980円画面・旧買い切り単独画面は提出しない。
