# 公開仕様と確認範囲

確認日：2026-10-21。公開ヘルプを参照。実口座・ログイン限定テンプレート・実サービス取り込みは未検証。ここで「確認済み」は記載された仕様を読めたという意味で、全金融機関の実CSV互換性を意味しません。

## 出力（公開仕様に基づく）

- freee「freeeに手動でアップロードする明細を用意する」
  https://support.freee.co.jp/hc/ja/articles/202847810
  銀行は日付・出金・入金・残高・内容、カードは日付・取引金額・内容・ラベル。カードは利用を正、返金を負とする。ヘッダー名は任意で、アップロード時に列を選択する方式。
- マネーフォワード「仕訳帳をインポートする」
  https://biz.moneyforward.com/support/account/guide/import-books/ib01.html
  A〜AAの27列、日付形式・貸借金額・科目・摘要・補足欄を確認。公式の仕訳帳CSV経路を採用し、明細Excelテンプレートの推定CSV化はしない。税区分等の登録先の設定、会計年度、最終確認は利用者が行う。
- 弥生「CSVファイル取込のファイル形式」
  https://support.yayoi-kk.co.jp/faq_Subcontents.html?page_id=23508
  スマート取引取込の7列、Shift-JIS、200KB未満、日付・入出金、摘要80文字・金額9桁等を確認。実装は余裕を持って190,000バイト未満に分割。見出し除外と項目の選択が必要。

## 入力（CSV提供の確認と形式推定を区別）

| 機関 | 公式資料 | 確認できた範囲 | 推定・未確認 |
|---|---|---|---|
| ゆうちょ | https://www.jp-bank.japanpost.jp/direct/pc/guide/dr_pc_gd_meisai.html | 個人向けCSVの取得導線 | 列名全体、列順、金額の符号、残高形式 |
| 楽天銀行 | https://www.rakuten-bank.co.jp/guide/withdrawal-details.html | CSVダウンロード提供 | 個人向けレイアウト・符号 |
| 楽天銀行（法人） | 下記法人FAQ | 日付/入出金(円)/残高(円)/入出金先内容の4項目 | 符号の詳細、個人向けへの適用 |
| 住信SBI | https://help.netbk.co.jp/faq_detail.html?id=834 | CSVダウンロードの提供 | 列名・列順・符号。確認時の現行サイトは「ドコモSMTBネット銀行」表記 |
| PayPay銀行 | https://www.paypay-bank.co.jp/account/report_time.html | 時刻付き明細もCSVを提供 | 列名・列順・符号、時刻欄の仕様 |
| 楽天カード | https://www.rakuten-card.co.jp/e-navi/p/rc/e-navi/statement/popup2.html | CSV提供、2行明細・リボ等の注意、利用店舗名項目の言及 | 全ヘッダー、符号、各種支払方式の厳密な対応 |

楽天銀行（法人）FAQ：
https://help-business.rakuten-bank.net/入出金明細でダウンロードできるCSVファイルの仕様、表示される項目を教えてください。-643cc75f407b9d001c61dbbe

推定入力の候補辞書・先頭50行の見出し提案は利用者が修正できる。候補一致を銀行公式の形式認証として扱わない。入力サンプルは全て架空・推定。今後は匿名化された公式サンプル等を確認して個別の対応精度を高める。
