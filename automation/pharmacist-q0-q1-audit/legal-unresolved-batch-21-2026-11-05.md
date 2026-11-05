# Q0 第21バッチ・A残2件

- P109-314：解消。2024-02-18試験日版臨床研究法第2条と1998年厚生省医薬審1047号ICH E9を照合。承認適応外使用の特定臨床研究該当性と事前規定PPSの低服薬遵守者除外、二重盲検の外観一致を確認。FAS/ITTから無条件に除外する主張ではないためQ1解説にも注記が必要。
- P110-140：保留。2026-04-01施行の環境基準改正注記をmainのオーバーライドデータに反映 commit c97c1f932ca98ed3db8a870cd5d1710326614f10。実際のアプリはproduct/questions.jsonから読み込むため、mainのproduct-loader-v06.jsにもP110-140改正注記を追加 commit dacee8528262e84003573108152865480088fc6a。双方のmainファイル再取得でコード反映確認。CI workflowはmainのproduct-loader-v06.js変更でトリガーされる設定だが、実行成功ログ・ビルド・生成配信物・TestFlightへの反映は確認できず。成功は主張しない。
- B7件は未調査。
- 解消1件、残8件（A1・B7）、保留8件。Q0 BLOCKED。App Review提出なし。

出典：
- https://www.mhlw.go.jp/web/t_doc?dataId=00ta7565&dataType=1&pageNo=1
- https://www.mhlw.go.jp/web/t_doc?dataId=80ab5894&dataType=0&pageNo=1
- https://www.env.go.jp/kijun/taiki.html
