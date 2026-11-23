# FP3 300問拡張・継続実装報告（2026-11-23）

## 結論

問題バンクの300問化は未完了。現行180問を維持し、未確認の過去問120問を推測で作成・混入しない方針を維持した。一方、既存問題の出典・加工表示UIと出典情報の監査ゲートを実装し、GitHub ActionsのFP3 PreflightおよびBrowser Visual Preflightが成功した。

## 今回の変更

1. `fp3-manabi-sprint/index.html`
   - 解答後の詳細解説欄に「出典・加工情報」を追加。
   - 問題ごとの `source_name`、`source_url`、`usage_note` を表示。
   - 公式原典リンクを別タブで開く。URLがない場合はリンクを表示しない。
   - 設定画面に現行180問の収録範囲、加工注記、日本FP協会の公開問題・利用条件へのリンクを表示。
2. `fp3-manabi-sprint/tools/audit_learning_bank.py`
   - 全問題に `source_name` とHTTPSの `source_url` が存在することを必須化。
3. `fp3-manabi-sprint/sources/FP3_2023_OFFICIAL_SOURCE_MANIFEST.md`
   - 2023年5月・9月の公式公開記録の所在を記録。
   - 公式PDFのバイナリ取得・全問照合は未完了であることを明記。
   - 先行記録にあった未検証の第三者PDF直リンク・許諾番号を、公式原典の取得証拠として扱わないよう訂正。
4. `fp3-manabi-sprint/audit/FP3_300_EXPANSION_SOURCE_GATE_20261123.md`
   - Q0原典確保をBLOCKEDに戻し、取得済みと未取得を区別。

## 現物確認

- 現行payload：180問
- 分野別：6分野各30問
- 形式：正誤90問、三択90問
- 既存180問の全件に `source_name` と `source_url` があることを確認。
- 既存180問の `usage_note` は問題単位ではなくpayload metadataに存在するため、UIは問題単位の値がない場合に共通加工注記を表示する。
- 2023年5月・9月の公式公開記録は確認したが、追加120問の問題PDF・正答PDFのバイナリ、SHA-256、60問・正答60個の直接照合は未完了。

## CI・ブラウザ検証

- FP3 Preflight：PASS
  - Run: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45181455993
  - web-preflight：PASS
  - ios-simulator：PASS
- FP3 Browser Visual Preflight：PASS
  - Run: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45181455988
  - mobile visual and premium interaction gate：PASS

## ゲート判定

| ゲート | 判定 | 理由 |
|---|---|---|
| Q0：追加120問の公式原典バイナリ確保 | BLOCKED | 公開記録の所在確認まで。問題PDF・正答PDFの現物取得と照合が未完了 |
| Q0：既存180問の出典表示 | PASS | 各問題の出典名・URLをUIに表示し、設定画面に利用条件を掲載 |
| Q0：出典情報のデータ品質 | PASS | 全180問にsource_name/source_url。監査スクリプトでも必須化 |
| Q1：追加120問の正答一意性・計算再検算 | NOT RUN | 追加問題が未収録 |
| Q1：300問全体監査 | NOT RUN | 300問未成立 |
| 300問正規バンク | BLOCKED | 現行180問のまま |

## 未完了・変更禁止範囲

- 2023年5月・9月の3級学科問題PDF・模範解答PDFを公式機関の配信元から取得。
- PDF SHA-256、ページ構成、全60問・全正答を照合。
- 120問の構造化、重複判定、2026-04-01法令照合、計算再検算、オリジナル解説、独立監査。
- 300問対応の監査スクリプト・materializer・payload・JSON参照ファイルの一体更新。
- 今回の担当範囲外のため、`ios/`、`project.yml`、`codemagic.yaml` は変更していない。

## 変更コミット

- UI出典表示：`cef2ada02e42041f0133e451c950a6a88f1b3c8b`
- 出典必須監査：`d77d98a555c19e26104d62a43d17812c20e574c8`
- 2023原典台帳訂正：`0b304e18dce01fb64e22cfbdbaf2525563dca3b3`
- Q0ゲート訂正：`5778c64d1609c58d9882ce84de35917bd2edf483`

この記録は、現行300問化が完了したという意味ではない。Q0原典確保とQ1監査が完了するまで、リリース判定はBLOCKEDとする。
