# HM2 C16差し替え後｜統合・二次担当チェックと代替検査（2026-11-22 JST）

配布bank Git blob `fc2c1dd22bf0699bb1da2ce49b0ddb4400fce556`。A blob `720b7187a9dada5e30131a1a5c0e118e7d87d580`、B blob `40420b50b02c19dc93a36b2309d1dc258c6a188c`、C blob `c75f38d7f9d94687d2b3464b43f3fe10bc8cfc9f`。
**この検査はGitHubから取得した実体ファイルに基づく静的検査であり、Node全量再生成、Python unittest18件、GitHub Actions成功とは別。**

## 二次チェックの実施と承認の区別
- 既存40問：各5肢の意味的再判定（計200肢）は別の二次レビュー記録で実施済み。ただし過去の一次記録を参照済みで盲検独立性は証明不能。
- A69問：一次69/69 PASS（Aの結論）、二次セッションの公式原典全345肢の独立照合は未完。
- B69問：一次PASS15/HOLD54（Bの結論）、二次側の公式原典逐肢照合は未完。
- 今回再設計したC16問は現行bank文面が変わり、古い一次・二次証跡の5肢文面一致は失効。旧判定の機械的流用禁止。
- 二次の対象ID確認は178/178。既存40問の二次意味チェック済40件。新Q0の真正な独立二重確認として正式承認済みは0/178。

## 代替静的チェック
|No.|実行項目|結果|
|---:|---|---|
|1|全300問|PASS|
|2|300ID重複なし|PASS|
|3|全300問5肢相異|PASS|
|4|正答位置0〜4|PASS|
|5|30群×10問|PASS|
|6|各群正答位置均等|PASS|
|7|既存40のID|PASS|
|8|A69のID|PASS|
|9|B69のID|PASS|
|10|178一意ID|PASS|
|11|178すべてbank内|PASS|
|12|C16一意|PASS|
|13|C16すべてbank内|PASS|
|14|C16全問非公開|PASS|
|15|C16全問再監査待ち|PASS|
|16|C16旧legalChecked失効|PASS|
|17|C13パッチ旧状態ガード|PASS|
|18|C3パッチ旧状態ガード|PASS|
|19|2つのCパッチに同一IDなし|PASS|
|20|3パッチexporterに登録|PASS|
|21|3パッチHTMLに登録|PASS|
|22|3パッチSWに登録|PASS|
|23|代替Q0ゲート強制維持|PASS|
|24|法令承認不足のリリース停止|PASS|
|25|Q0に独立session要件|PASS|
|26|Q0に無参照宣誓要件|PASS|
|27|Python回帰定義18ケース|PASS|
|28|C対象の正答妥当文字列|PASS|

**28/28 PASS**。

## 差し替えの運用安全策
- Cフラグ16/16に代替設問を生成元パッチ＋Web読込＋配布JSONとして実装。3問は前コミット、13問は追加コミット。全16問が再監査待ち／非公開／旧legal_checked無効。
- 差し替え後の個別原典・権利・他問題との意味重複・全肢正誤の完全監査は残件。C運用PASS284/300は著作権最終承認ではない。
- 正規exporterは独立Q0証跡と法令確認を要求するため、今回の監査失効16問を無条件に本番配信できない。

## 実行困難と再判定
- `git ls-remote https://github.com/...` は `Could not resolve host: github.com`。ローカルcheckoutできないためNode再生成・Python unittest18件を実行不能。
- GitHub接続には新規workflow_dispatchのアクションが存在しない。今回のコミットに対するCI成功証跡は別途確認が必要。
- よって **Q0 BLOCKED / Q1 BLOCKED**。App Review／TestFlight新規配信なし。
