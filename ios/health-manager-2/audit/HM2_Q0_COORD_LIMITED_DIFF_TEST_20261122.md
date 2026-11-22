# HM2 Q0 コーディネーター限定差分テスト：更新後bank（2026-11-22）

変更前Git blob `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`、変更後Git blob `b954a6b8c0606f5c34589b7b7eafd269bbe65489`。Github連携から読み込んだ現行300問と生成元2パッチ・HTML・SW・exporter・Q0ゲートコードに対し、JavaScript静的検査をこのセッションで実行した。
**これはオリジナルのPython unittest18件、Node CLI再生成、ブラウザ統合、GHAの実行ではない。**

変更ID: `sm2-demo-001`、`sm2-demo-002`、`sm2-demo-003`、`sm2-5y-r05-hyg-05`、`sm2-5y-r07-hyg-08`

|No.|検査|結果|
|---:|---|---|
|1|300問維持|PASS|
|2|300ID一意|PASS|
|3|全5肢|PASS|
|4|各5肢が相異|PASS|
|5|正答indexは0-4|PASS|
|6|30群が存在|PASS|
|7|各群10問|PASS|
|8|各群で正答位置各2問|PASS|
|9|差分5IDに限定|PASS|
|10|他295問に変更なし|PASS|
|11|換気2問は本文と5肢不変|PASS|
|12|換気2問は正答不変|PASS|
|13|換気2問AIST出典|PASS|
|14|3設問の問題文変更|PASS|
|15|3設問の承認日を無効化|PASS|
|16|3設問が非公開|PASS|
|17|3設問の監査状態保留|PASS|
|18|生成元換気パッチに旧状態ガード|PASS|
|19|生成元Cパッチに旧状態ガード|PASS|
|20|生成元Cパッチは未承認法令を拒否|PASS|
|21|exporter両パッチを読込|PASS|
|22|web側両パッチを読込|PASS|
|23|SW両パッチをキャッシュ|PASS|
|24|exporterのQ0強制ゲート維持|PASS|
|25|exporterの法令再確認ゲート維持|PASS|
|26|Python回帰テスト定義18件|PASS|
|27|独立セッション要件維持|PASS|
|28|先行監査非参照宣誓要件維持|PASS|

**静的検査 28/28 PASS。**

- Cの3問は新しい問題に差し替え、旧法令承認を無効化して『再監査待ち・非公開』を設定。未承認状態で正規exporterを実行すると fail-closed となる設計。
- GHAはこのGitHub連携でworkflow_dispatchの新規起動操作を利用できず、環境のgitは `Could not resolve host: github.com`。
- Python回帰18件の実測は未実行。原典権利・独立二次チェックの最終合格は今回の静的検査で証明できない。
