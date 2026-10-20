# 実行環境

- 実行日: 2026-10-20 UTC。Linux / Debian 13（doctor報告）。
- Node: v24.19.0、npm: 11.9.0。追加導入なし。
- 公開npmパッケージREA: 6.7.0。analyzer provider: rea-javascript-application version 1。
- REA保存先checkout: /workspace/rea、取得時commit 52d1a72af047a73b787b8935b032786a34966036。
- 対象: /tmp/targets/excalidraw、commit bee01e3a12812c930109aa91242658709480bbf3、MIT。
- 公開版CLIの実行cwd: /tmp（checkout内でnpxを実行すると未ビルドのローカルbinが優先されたため）。
- setup: 非対話、設定変更0件。doctor: audit-wideで不健康。対象指定のdoctorも不健康。詳細はdoctor.json / doctor-target.json。
- 初期ネットワーク: サンドボックスからプロキシ接続がEPERMで失敗。セッションの権限変更後は継承されたプロキシ設定のままclone/npm取得が成功。プロキシ迂回やTLS検証無効化は行っていない。
- REA解析: 2026-10-20T14:03:54.418958+00:00開始、66.411秒、終了コード0。graph coverage=partial。完全解析成功とはしない。
- 所要時間はPython time.monotonic()で測ったサブプロセスの壁時計時間。CPU時間・ピークメモリ・トークン使用量は未測定。
- stdoutはraw.json.gzとして可逆圧縮保存し、stderrの進捗はanalyze.stderrとrun.logに保持。JSONを整形・置換していない。APIキー・トークン・環境変数全量は保存していない。

実際のコマンド・終了コードはcommand-results.mdおよびcommands.json。raw.json.gzは原本の可逆圧縮版。SHA256SUMSでファイル同一性を確認できる。

## 公開先への移送

- 保存先: ALLSUNDAY1122/ALLSUNDAY1122.github.io、ブランチ research/rea-first-run。
- 圧縮サイズ: 23,576,915 bytes（50,000,000 bytes未満）。分割不要。
- 未圧縮raw.jsonは本リポジトリに追加しない。本文・ログのraw.json参照は圧縮ファイル展開後の原本を指す。
- 今回の移送でREA解析を再実行していない。初回実行の出力とその来歴を維持する。
