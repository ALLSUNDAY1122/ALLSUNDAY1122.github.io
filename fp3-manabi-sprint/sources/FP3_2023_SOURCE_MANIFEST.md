# FP3級 2023年5月・9月 公式原典台帳

確認日：2026-11-23（Asia/Tokyo）
対象リポジトリ：ALLSUNDAY1122/ALLSUNDAY1122.github.io
対象アプリ：fp3-manabi-sprint

## 原典バイナリ

添付資料から問題PDF2点・模範解答PDF2点の実バイナリを作業環境へ展開し、SHA-256を再計算した。4ファイルともSOURCES.txtの記録値と一致した。問題PDFはpdftotextで抽出し、各回に問(1)～(60)が存在することを確認した。

| 試験回 | 資料 | バイト数 | SHA-256 |
|---|---|---:|---|
| 2023年5月28日 | 学科問題 | 379,038 | 684b046bd8d43575aa135ad3f3454f11108eb68577af7f91f331a0fcb058e350 |
| 2023年5月28日 | 学科解答 | 48,864 | a0af4d7d3137718bbf6df7617f6393069934bf98475aef2b9c168d1f2b76977c |
| 2023年9月10日 | 学科問題 | 345,604 | efdb34aaa1c520c6c8cf4b7e47caaf038d92c16e0e9d2579016ab455646af1ca |
| 2023年9月10日 | 学科解答 | 58,416 | 28ddc53e735a2bf076cf0a0c2571e88e744cffc326df0e773f42eac1976798d1 |

## 原典URL・取得経路

日本FP協会の公式ファイルURLは2026-11-23時点でライブ404。取得した原典は日本FP協会公式URLのInternet Archiveスナップショット（id_原ファイル）。

- 2023年5月 問題：https://web.archive.org/web/20251205024627id_/https://www.jafp.or.jp/exam/mohan/files/g3_202305_q.pdf
- 2023年5月 解答：https://web.archive.org/web/20251205021959id_/https://www.jafp.or.jp/exam/mohan/files/g3_202305_a.pdf
- 2023年9月 問題：https://web.archive.org/web/20241125112258id_/https://www.jafp.or.jp/exam/mohan/files/g3_202309_q.pdf
- 2023年9月 解答：https://web.archive.org/web/20241125094940id_/https://www.jafp.or.jp/exam/mohan/files/g3_202309_a.pdf

原典URL（日本FP協会）：
- https://www.jafp.or.jp/exam/mohan/files/g3_202305_q.pdf
- https://www.jafp.or.jp/exam/mohan/files/g3_202305_a.pdf
- https://www.jafp.or.jp/exam/mohan/files/g3_202309_q.pdf
- https://www.jafp.or.jp/exam/mohan/files/g3_202309_a.pdf

## 利用条件

日本FP協会「FP技能検定の試験問題の利用について」：
https://www.jafp.or.jp/exam/mohan/files/exam_riyou.pdf

同文書では、3級学科試験問題の著作権が日本FP協会にあること、利用時は出典を明記すること、修正・加工した場合はその旨を明記すること、利用申請は不要であることが示されている。

各問の出典表示：
- 日本FP協会 3級ファイナンシャル・プランニング技能検定学科試験 2023年5月
- 日本FP協会 3級ファイナンシャル・プランニング技能検定学科試験 2023年9月

問題文・選択肢を加工した設問には、続けて「を加工して作成」と表示する。原文をそのまま使用する場合は加工表示を付けない。

## 収録・監査上の注意

- 公式解答番号は2023年当時の公表正答として保持し、現行法に合わせて書き換えない。
- 2026-04-01時点の法令・制度と異なる設問には、公式正答とは別の現行制度注記を設ける。
- 公式問題・解答との問別照合、正答番号照合、選択肢数・型・IDの検査を別々に実施する。
- 現行法注記と解説の監査が終わるまでは、追加120問を監査済みPASSと表示しない。
- 原典PDFの確保と60問存在の確認は完了したが、120問の既存スキーマへの転記・監査・アプリ統合は未完了。

## 2026-11-23時点の実装基準点

- 作業開始時main HEAD：e7e92f1f6970a2d889e67d93f86f69bb9a3958f1
- 現在のmain HEADはGitHubのブランチ参照を確認すること。
- 既存問題数：180問（正規payload）
- 追加対象：2023年5月60問、2023年9月60問
- 目標問題数：300問
- 原典確保：PASS
- 問別転記・正答照合・現行法監査・解説監査・300問統合：未完了

## 追加した自動検査（2026-11-23）

- `tools/audit_2023_source_transcriptions.py` を追加し、2023年5月・9月の各60問の番号連続性、正誤式30問・三択式30問、模範解答PDFから抽出した60個の正答番号と固定照合ベクトルの一致を検査する。
- `.github/workflows/fp3-preflight.yml` に上記検査を組み込んだ。
- この検査は原典転記と正答キーの基礎検査であり、現行法監査・解説監査・300問バンク統合の代替ではない。
