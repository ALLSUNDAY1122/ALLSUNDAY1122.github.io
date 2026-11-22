# HM2 コーディネーター｜代替テスト実行記録（2026-11-22）

対象：GitHub接続から取得したbank・A/B/C・ゲートPythonコード・元テスト定義を入力として、このセッションでJSによる**静的検査18件を実際に実行**した結果。**元のPython unittest 18件を実行した結果ではない**。実際のNodeエクスポート・生成元再生成・GHAの成功は未確認。

対象bank Git blob: `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`。
ゲートblob: `10965144614f4b4754082264b5944d3b91347074`、テスト定義blob: `128a43349a8582efd40c6ce63ab69e2eb9356335`。

|No.|静的検査項目|実測|
|---:|---|---|
|1|銀行300件|PASS|
|2|銀行ID300件一意|PASS|
|3|銀行各5肢|PASS|
|4|銀行正答index範囲|PASS|
|5|銀行参照URL全件|PASS|
|6|銀行権利自己申告全件|PASS|
|7|既存40ID|PASS|
|8|A割当69ID|PASS|
|9|B割当69ID|PASS|
|10|A/B既存の相互非重複|PASS|
|11|178ID銀行全件に存在|PASS|
|12|C主一覧300ID|PASS|
|13|C銀行集合一致|PASS|
|14|代替ゲート独立session ID要求|PASS|
|15|代替ゲート非閲覧宣誓要求|PASS|
|16|代替ゲート監査artifact SHA要求|PASS|
|17|代替ゲート権利300件照合|PASS|
|18|元Python回帰テスト定義18件|PASS|

結果：**18/18 PASS**（静的検査に限定）。

## 非実行の理由
- この実行環境でGitHubドメインのDNS解決に失敗し、checkoutが取得できない（`Could not resolve host: github.com`）。したがって正式なPython unittest18件およびNode CLIのローカル実行は不可。
- 現接続のGitHub操作には新規GitHub Actions workflow_dispatch/手動実行がなく、既知の既存失敗ジョブIDもないためGHAを起動できない。
- 元Pythonテストの18個の関数の存在確認とそのロジックを実行したことは区別する。**Python18テストの実測PASSは0件、未実行18件**。
- この静的検査は根拠や法令の真偽、レビュー独立性、著作権の適法性を検証するものではない。Q0/Q1 BLOCKEDを維持。
