# Q0 P110-140・第22バッチ｜main生成済みデータ・ビルド・配信・Internal TF検証

実施日：2026-11-05

- 対象：P110-140のみ。B7件は調査せず。
- 以前の変更：mainのthird-party-replacements.json（commit c97c1f932ca98ed3db8a870cd5d1710326614f10）およびproduct-loader-v06.js（commit dacee8528262e84003573108152865480088fc6a）に試験日と2026年4月改正との差分を明記。
- 今回の追加確認：mainの `pharmacist-manabi-sprint/content/product/questions.json`（GitHub blob SHA `06066d711d152e36a96e844766c1a358c9afd8b7`）を直接取得。全1035問をJSON解析し、P110-140の `explanation` と `memoryPoint` に改正注記が存在、`answer=[1,4]` で試験日2025-02-23の正答は維持。
- GitHub main上のソースと**生成済み配信元JSONには反映を確認済み**。ただし公開配信サーバーのレスポンスは未確認。
- ビルド：修正後のCI workflow成功ログ・成果物を取得できず**未確認**。GitHub commit statusesは空、PRトリガーのworkflow run取得数0。mainのCI workflowはproduct-loader-v06.jsのpushを監視する設定。2026-08-09のweb/record smoke exit=0は改修前であり今回の成功証跡として採用しない。
- Internal TestFlight：ビルド番号、処理完了状態、インストール後表示確認を取得できず**未確認**。ビルドやTFアップロードを完了したとは記載しない。
- 今回の解消：0件。Q0残8件（A1・B7）。Q0最終判定：**BLOCKED**。
- 本番App Review：**未提出・操作なし**。
