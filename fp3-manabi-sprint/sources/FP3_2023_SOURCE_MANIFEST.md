# FP3級 2023年5月・9月 公式原典台帳

確認日：2026-11-23（Asia/Tokyo）
対象リポジトリ：ALLSUNDAY1122/ALLSUNDAY1122.github.io
対象アプリ：fp3-manabi-sprint

## 原典と完全性

| 試験回 | 資料 | 原典URL | SHA-256 |
|---|---|---|---|
| 2023年5月28日 | 学科問題 | https://www.jafp.or.jp/exam/mohan/files/g3_202305_q.pdf | 684b046bd8d43575aa135ad3f3454f11108eb68577af7f91f331a0fcb058e350 |
| 2023年5月28日 | 学科解答 | https://www.jafp.or.jp/exam/mohan/files/g3_202305_a.pdf | a0af4d7d3137718bbf6df7617f6393069934bf98475aef2b9c168d1f2b76977c |
| 2023年9月10日 | 学科問題 | https://www.jafp.or.jp/exam/mohan/files/g3_202309_q.pdf | efdb34aaa1c520c6c8cf4b7e47caaf038d92c16e0e9d2579016ab455646af1ca |
| 2023年9月10日 | 学科解答 | https://www.jafp.or.jp/exam/mohan/files/g3_202309_a.pdf | 28ddc53e735a2bf076cf0a0c2571e88e744cffc326df0e773f42eac1976798d1 |
| 利用条件 | 試験問題の利用について | https://www.jafp.or.jp/exam/mohan/files/exam_riyou.pdf | db604850c3f14cab982bedf622beae6f33d0624dd79f8dc8f9baaa979e00df45 |

各ファイルのSHA-256は、今回受領した添付PDFの実バイト列から再計算し、上記値と一致することを確認した。

## 取得経路と公開状態

2023年分の公式ファイルは、2026-11-23時点で日本FP協会のライブURLが404となることを確認。取得記録にあるInternet Archiveスナップショット（id_原ファイル）は次のとおり。

- 2023年5月 問題：https://web.archive.org/web/20251205024627id_/https://www.jafp.or.jp/exam/mohan/files/g3_202305_q.pdf
- 2023年5月 解答：https://web.archive.org/web/20251205021959id_/https://www.jafp.or.jp/exam/mohan/files/g3_202305_a.pdf
- 2023年9月 問題：https://web.archive.org/web/20241125112258id_/https://www.jafp.or.jp/exam/mohan/files/g3_202309_q.pdf
- 2023年9月 解答：https://web.archive.org/web/20241125094940id_/https://www.jafp.or.jp/exam/mohan/files/g3_202309_a.pdf

## 利用条件

添付された日本FP協会「FP技能検定の試験問題の利用について」には、3級学科試験問題の著作権が日本FP協会にあること、利用時は出典を明記すること、修正・加工した場合はその旨を明記すること、利用申請は不要であることが記載されている。

アプリ内の出典表示は次の形式とする。

- 日本FP協会 3級ファイナンシャル・プランニング技能検定学科試験 2023年5月
- 日本FP協会 3級ファイナンシャル・プランニング技能検定学科試験 2023年9月

問題文・選択肢を加工した設問には、続けて「を加工して作成」と表示する。原文をそのまま使用する場合は加工表示を付けない。

## 収録・監査上の注意

- 公式解答番号は2023年当時の公表正答として保持し、現行法に合わせて書き換えない。
- 2026-04-01時点の法令・制度と異なる設問には、公式正答とは別の現行制度注記を設ける。
- 公式問題・解答との逐語照合、正答番号照合、選択肢数・型・IDの検査を別々に実施する。
- 現行法注記と解説の監査が終わるまでは、追加120問を監査済みPASSと表示しない。
- この台帳の作成だけでは、アプリへの120問追加や300問化完了を意味しない。

## 2026-11-23時点の実装基準点

- 作業開始時main HEAD：e7e92f1f6970a2d889e67d93f86f69bb9a3958f1
- 既存問題数：180問（正規payload）
- 追加対象：2023年5月60問、2023年9月60問
- 目標問題数：300問
