# FP2・FP3 並列テーマ台帳（唯一の取得正本）

更新: 2026-11-08 JST / ブランチ: `codex/fp-parallel-themes-20261108` / リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`

## 排他取得ルール

1. 各セッションは `PARALLEL_SESSION_PROMPT.md` を読み、このブランチを `pull --ff-only` する。依存欄の全テーマがDONEで、状態OPENの行だけが取得可能。
2. 取得者は当該行のみCLAIMEDに更新し、`owner`（固有SESSION-ID）と`claimed_at`（ISO8601 Asia/Tokyo実時刻）を記録。**claimコミットのpush成功のみ取得確定**。競合したら最新台帳から取り直して次のOPENを選ぶ。force pushは禁止。
3. 取得コミットSHAを次回成果コミットで `claim_commit` に反映。完了時には自身の行のみDONEまたはBLOCKEDへ変更し、`completed_at`、`evidence`、未達理由を記録してpushする。
4. CLAIMEDは期限切れを理由に自動OPENへ戻さない。担当者との照会または根拠付き管理者調整のみで再割当。DONEの根拠ファイルと実検証がない場合、DONEにしてはならない。
5. 各テーマは指定の専用成果ファイルを主とし、共通正本への変更は統合担当に限定。監査中のFP3ロック済み問題バンクとSOURCE_LOCKは書換禁止。FP2 A01独自作問は製品数へ計上禁止。

**状態定義:** OPEN=取得可能（依存が完了している場合のみ） / CLAIMED=排他取得済み・作業中 / DONE=成果と検証をpush済み / BLOCKED=外部承認・原資料欠落等で着手/完了不可。依存未完了のOPENは取得不可。

## 現状と保護対象

- FP3監査の**集約値**（主監査記録第3回20問＋2025年度シャード20問＋2026年度シャード20問）は**180問中60問判定済み（合格46・要修正4・保留10）、未判定120問**。主監査記録 `fp3-manabi-sprint/audits/CONTENT_REAUDIT_20261108.md` 自体の集計はまだ20問であり、ここでの60問は3ファイルのID非重複集計。追加シャード・他セッションの追記は作業開始前に再確認。
- 既判定ID: `2024-04`（合格）、`2024-48`・`2024-53`（要修正）、`2025-01`～`2025-20`（合格11・要修正2・保留7）、`2025-26`（合格）、`2026-01`～`2026-15`（合格15件）、`2026-16`～`2026-19`・`2026-21`～`2026-36`（合格18・保留2）、`2026-20`（保留）。要修正4問は `2024-48`,`2024-53`,`2025-15`,`2025-17`。判定済みのシャードIDを再監査しない。`2026-20`の保留再判定は`FP3-26-HOLD`のみ。要修正4問への反映は`FP3-FIX-2`が専任。
- Muse/Claude担当の2025年度シャード（`FP3-25-CLAUDE`、`826bfe9e817006d3e0193481ba99622ce41780ca`、2025-01～20）と2026年度シャード（`FP3-26-CLAUDE`、`5f184b977aaa8e2d0fc10ed4db9f146cd547b8c5`、2026-16～19・21～36）は**ともにDONE**。成果の元ブランチは `codex/fp-release-preparation-20261107`。依存していた2025/2026残範囲テーマは取得可能。ただし各テーマはこれら既判定IDを除外する。
- FP3の累計は主監査20問＋外部シャード40問＝60問（合格46・要修正4・保留10）。監査の合格は制度論点の判定であって原典全選択肢の逐語照合完了ではない。製品ゲートはBLOCKED。
- FP3 AppIcon正本・XcodeGen・Simulatorビルドは既存のCI実績があるが、FP3専用Preflightワークフロー実行は未確認。`FP3-PREFLIGHT` はこの残件だけを調べる。
- FP2公式過去問500問は**検証前の計画目標**。原典の実数、利用条件、学科/実技の回次を確認するまで完成数と断定しない。旧180問は再利用が自動承認されたわけではない。FP2の従前 `CONTENT_BATCH_PLAN.md` の独自600問方針は今回の製品方針と不一致であり、製品へは適用しない。
- FP2旧180問「R1～R3」は仮の回次グループ識別子。実際の原典回次と旧180問の対応・件数を最初に確認し、**IDの昇順で原典回次を並べた第1・第2・第3群**として固定する。180問の実回次数が3でない場合は成果をBLOCKEDにして管理者へ分割修正を要求し、同じ原典回次を複数担当へ割り当てない。回次未確定時の推測による監査は不可。
- **FP2-OLD-R1/R2/R3共通前提（2026-11-09更新）:** 旧180問の監査台帳にはID・回次・問番号・正答・原典URL・法令基準日などのメタデータのみがあり、問題文・選択肢・解説の実体はない。旧台帳の「済」は再検証PASSを意味しない。R1は正答・基準日・原典URLの照合工程を完了し、残る原典逐語照合・解説・出典/加工表示・権利確認は**公式問題のデータ化工程に統合**する。R2/R3も同じ前提で、既存正答はデータ化時の照合材料にすぎない。**R1のDONEは製品採用承認を意味しない**（R1 PASS0/UNVERIFIED60）。R2/R3はOPENを維持し、未照合を合格扱いしない。
- FP2学科/実技シャードA/Bは原本台帳で確定する「未収録分」の原典回次・IDを昇順ソートし、連続する前半/後半に分割する（奇数件では前半が1件多い）。旧180問で再利用承認となったIDを除く。原本台帳未確定時は依存未完了として取得しない。

## テーマ一覧

| ID | 対象 | テーマ・排他範囲 | 状態 | 依存（全DONEが必須） | owner | claimed_at | claim_commit | completed_at | evidence / 主な許可出力 |
|---|---|---|---|---|---|---|---|---|---|
| FP3-24-A | FP3 | 2024年度01–20（既判定04を除外）一次資料再監査 | DONE | - | MUSE-EXT-24A | 2026-11-09T06:19:32+09:00 | 694f3ef39a678637b7ba8c003ab764a0b446d688 | 2026-11-09T06:22:16+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2024_01_20.md` / 82d6dc6bddec57c180abc23f436749f2f2da30c1 / 制度論点PASS19・FAIL0・UNVERIFIED0、04除外、原典逐語照合19件未実施・製品ゲートBLOCKED |
| FP3-24-B | FP3 | 2024年度21–40 一次資料再監査 | DONE | - | MUSE-EXT-24B | 2026-11-09T06:24:00+09:00 | 06694698bbfb30be23a2a2e48720dde8bbe99ca9 | 2026-11-09T06:29:00+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2024_21_40.md` / 0ed5160ed672f69cbea5e55cb88865781d141730 / 制度論点PASS15・FAIL0・UNVERIFIED5、原典逐語照合20件未実施・製品ゲートBLOCKED |
| FP3-24-C | FP3 | 2024年度41–60（既判定48・53を除外）一次資料再監査 | DONE | - | MUSE-EXT-24C | 2026-11-09T06:41:51+09:00 | f2b69e1a2007812ec028a3775e6a7cd30a3d8781 | 2026-11-09T06:44:10+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2024_41_60.md` / 96c0228358c6909927dacf2f92d11447a366352c / 制度論点PASS16・FAIL0・UNVERIFIED2（41・43）、既判定48・53除外、原典逐語照合18件未実施・製品ゲートBLOCKED |
| FP3-25-CLAUDE | FP3 | 2025年度01～20の20問（合格11・要修正2・保留7） | DONE | - | MUSE-EXTERNAL | 取得時刻未確認 | external-unverified | 2026-11-08（コミット日・時刻の詳細は当該コミット） | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2025.md` / `826bfe9e817006d3e0193481ba99622ce41780ca` |
| FP3-26-CLAUDE | FP3 | 2026年度16～19・21～36の20問（合格18・要修正0・保留2） | DONE | - | MUSE-EXTERNAL | 取得時刻未確認 | external-unverified | 2026-11-08（コミット日・時刻の詳細は当該コミット） | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2026.md` / `5f184b977aaa8e2d0fc10ed4db9f146cd547b8c5` |
| FP3-25-A | FP3 | 2025年度01–20は全件判定済み：重複監査禁止 | DONE | FP3-25-CLAUDE | - | - | - | 2026-11-08（外部シャード） | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2025.md` / 826bfe9 |
| FP3-25-B | FP3 | 2025年度21–40（26既判定除外）を監査 | DONE | FP3-25-CLAUDE | MUSE-EXT-25B | 2026-11-09T06:19:37+09:00 | abe7672ca123e01a275b55fd7f738bfd6aff77b2 | 2026-11-09T06:21:55+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2025_21_40.md` / 880e44a / 19件 PASS18 FAIL0 UNVERIFIED1（2025-25保留）、原典逐語照合未完 |
| FP3-25-C | FP3 | 2025年度41–60を監査 | DONE | FP3-25-CLAUDE | MUSE-EXT-25C | 2026-11-09T06:41:47+09:00 | 56523947df028266aaa01091251f3af9e85431b0 | 2026-11-09T06:48:00+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2025_41_60.md` / a9b954de3a44c707a9359fb9d9d858c3e6ec9df9 / 制度論点PASS19 FAIL0 UNVERIFIED1（53）、公式問題逐語照合20件未実施・製品ゲートBLOCKED |
| FP3-26-A | FP3 | 2026年度16–35は全件判定済み：重複監査禁止 | DONE | FP3-26-CLAUDE | - | - | - | 2026-11-08（外部シャード） | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2026.md` / 5f184b9 |
| FP3-26-B | FP3 | 2026年度37–60を監査（36判定済み） | DONE | FP3-26-CLAUDE | MUSE-EXT-26B | 2026-11-09T06:51:00+09:00 | c2ca49b295eab59cd9291cb7388fcbba0ba1c40d | 2026-11-09T06:59:00+09:00 | `fp3-manabi-sprint/audits/parallel/FP3_2026_36_60.md` / 331224e0466b9f19260e2a54bc69f38cafb7b6f5 / 制度論点PASS22 FAIL0 UNVERIFIED2（38・57）、公式問題逐語照合24件未実施・製品ゲートBLOCKED |
| FP3-26-HOLD | FP3 | 2026-20保留の施行日・法令基準日照合と判定 | DONE | - | MUSE-EXT-HOLD-RESOLVE | 2026-11-09T07:10:00+09:00 | 04c5997f26d49bb2751f8b5a38bea5a807519e02 | 2026-11-09 JST | `fp3-manabi-sprint/audits/parallel/FP3_HOLD_RESOLUTION.md` / c7ad2f20a60df257d401316df0323975385cd34c / 2026-20制度論点PASS・解説時点の改訂未適用。保留21問を追加照合しPASS16・UNVERIFIED5（2024-41,2025-08,2025-09,2025-25,2026-57）。全件解消ではなく製品ゲートBLOCKED維持 |
| FP3-FIX-2 | FP3 | 4問（2024-48/53・2025-15/17）の解説/文言修正（ロック解除承認待ち） | BLOCKED | FP3-24-C | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_EXPLANATION_FIX.md` / 0de72d104654b0767e60b7272a08f335213c250f / 2026-11-09：SOURCE_LOCKに解除承認者・解除/再ロック手順なし。4問修正案整理、適用0/4、後検証未実施。管理者・統合担当承認と正式手順整備までBLOCKED、製品ゲート維持 |
| FP3-PREFLIGHT | FP3 | FP3専用Preflight実行・XcodeGen/Simulator結果記録（既成功と再実行を区別） | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_PREFLIGHT.md` |
| FP3-CONSOLIDATE | FP3 | 年度シャードを正本へ統合し180問の重複・欠番・判定集計・原典照合ゲート確認 | OPEN | FP3-24-A,FP3-24-B,FP3-24-C,FP3-25-A,FP3-25-B,FP3-25-C,FP3-26-A,FP3-26-B,FP3-26-HOLD,FP3-FIX-2 | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_CONSOLIDATION.md` |
| FP2-SOURCE | FP2 | 公式過去問原本・許諾条件・回次別学科/実技実数台帳（計画500と実数を分離） | DONE | - | MUSE-EXT-SRC | 2026-11-09T06:19:24+09:00 | 9ca2a98801d922c02a028b9f063b720b942e764e | 2026-11-09T06:27:00+09:00 | `fp2-manabi-sprint/audits/parallel/FP2_OFFICIAL_SOURCE_LEDGER.md` / 500819800b2382b1159bef14fcbaa109737c48ca / 実技法令基準日5回次、旧学科180問=3回次各60確認。旧個票採否・CBT個別設問日付は後続監査 |
| FP2-OLD-R1 | FP2 | 旧180問の原典回次第1群：正答・法令基準日・原典URL照合（実体再検証はデータ化工程へ統合） | DONE | - | MUSE-EXT-R1 | 2026-11-09T06:34:00+09:00 | 49c17476424f9aac3aa09d6dc426d91c66e739ec | 2026-11-09T06:37:23+09:00 | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_01.md` / 511359ee4ff6e6059beb75c5cc7563c46a0b2e6e / 第1群2025-01学科60件：旧台帳の正答・法令基準日・原典URL・問番号の照合まで完了（一致60、正答不一致0）。旧180問台帳には問題文・選択肢・解説の実体データが存在しないため、原典逐語再検証・表示/権利確認は公式過去問のデータ化工程へ統合。これはメタデータ照合工程のDONEであり、製品採用PASS0・UNVERIFIED60・採用承認0。 |
| FP2-OLD-R2 | FP2 | 旧180問の原典回次第2群（2025-05学科60件）：正答等の照合材料確認。問題文・選択肢・解説の実体なし、原典逐語照合はデータ化工程へ統合 | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_02.md` / 旧台帳の正答・基準日・URLはデータ化時の照合材料に限定。原典照合や製品承認済みと数えない。 |
| FP2-OLD-R3 | FP2 | 旧180問の原典回次第3群（2026-05学科60件）：正答等の照合材料確認。問題文・選択肢・解説の実体なし、原典逐語照合はデータ化工程へ統合 | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_03.md` / 旧台帳の正答・基準日・URLはデータ化時の照合材料に限定。原典照合や製品承認済みと数えない。 |
| FP2-ACA-A | FP2 | 公式学科の未収録分：原典台帳順の前半をデータ化 | BLOCKED | FP2-SOURCE | MUSE-EXT-ACAA | 2026-11-09T06:52:00+09:00 | 8c2c4910cc3ee97616af3d65b4b943f4ca92eb46 | 2026-11-09T06:52:00+09:00 | `fp2-manabi-sprint/batches/official/academic_part_a.json` / 3195b9b8701186f25025dc4bcb37a001dfb1a08f / 2024-05・09各60件、計120件のID・原典URL・法令日・公式正答を収録。問題文・全選択肢・図表転記0、解説未作成、製品承認0。PDF本文の完全転記・照合が未完了のためBLOCKED |
| FP2-ACA-B | FP2 | 公式学科の未収録分：原典台帳順の後半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/academic_part_b.json` |
| FP2-PRAC-A | FP2 | 公式実技未収録分：原典台帳順の前半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/practical_part_a.json` |
| FP2-PRAC-B | FP2 | 公式実技未収録分：原典台帳順の後半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/practical_part_b.json` |
| FP2-GATES | FP2 | 固定500/600前提を廃止し実数・出典対応・重複・権利で判定する検査ゲートを改修 | DONE | FP2-SOURCE | MUSE-EXT-GATE | 2026-11-09T06:34:00+09:00 | 8f2f12c0821872629e0c5ed23f75b3e3c2e3da0b | 2026-11-09T06:57:00+09:00 | `fp2-manabi-sprint/audits/parallel/FP2_REAL_COUNT_GATES.md` / d96af77d93cb / Actions 42527638041 専用10/10・共通10/10 PASS、失敗0、現行製品FAIL-closed検証PASS、旧600問実行時参照を修正、製品リリースはBLOCKED |
| FP2-MERGE | FP2 | 監査合格の公式過去問シャードのみ製品JSONへ統合、A01独自問題除外 | OPEN | FP2-OLD-R1,FP2-OLD-R2,FP2-OLD-R3,FP2-ACA-A,FP2-ACA-B,FP2-PRAC-A,FP2-PRAC-B,FP2-GATES | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_PRODUCT_MERGE.md` |
| FP2-UI | FP2 | FP2製品UIを公式過去問スキーマに移行・暫定モックで画面検証 | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_UI_MIGRATION.md` |
| FP2-E2E | FP2 | 製品JSON実数・UI・CI・権利表示の最終統合検査 | OPEN | FP2-MERGE,FP2-UI | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_E2E.md` |

## 保留解消追加照合（2026-11-09）

- `FP3_HOLD_RESOLUTION.md` に一次判定の保留21問を集約：**制度論点PASS16、UNVERIFIED5、FAIL0**。未解消5問（2024-41、2025-08、2025-09、2025-25、2026-57）は別途一次資料・条件修正待ちであり製品採用不可。`FP3-26-HOLD` のDONEは2026-20個別の制度論点確定を意味し、21問全件解消を意味しない。2026-20は2026年度税制改正の施行日と適用年分を解説へ追記する作業が未完。製品ゲートBLOCKED継続。

## 完了条件と依存上の注意

- 各監査成果は対象ID、原典/法令の一次資料URL、対象基準日、確認範囲、PASS/FAIL/UNVERIFIED相当判定、問題数と未完了件数を残す。取得後に既判定やMuse取得IDを発見した場合はスキップし理由を記載。
- `FP3-25-CLAUDE`/`FP3-26-CLAUDE` は指定コミットで成果を確認しDONEに変更済み。依存が解けた他テーマでも、判定済みの2025-01～20・2026-16～19/21～36は再担当しない。`FP3-25-A`/`FP3-26-A` は全対象判定済みのため作業不要DONEとし、成果は各CLAUDEシャードを参照する。
- `FP3-FIX-2` は対象4問（2024-48・2024-53・2025-15・2025-17）。2025-15は犯収法の確認記録/取引記録文言区別、2025-17は2024年分と2025年分以降の給与所得控除の時点区別。ロック済みデータの編集承認とソースロック解除手順が未確認のためBLOCKEDを維持し、問題文言の変更可否も別途判断する。
- `FP3-CONSOLIDATE` は各年度の監査ファイルを集計する。製品ゲート解除は全180問の必要な原典照合・解説反映検証完了と別判定。監査ログの単純集計をリリース承認としない。
- `FP2-SOURCE` は公表物を収集・出典識別子を定義し、正規の使用条件と加工明示を記載。 `FP2-OLD-R*` は先行して旧データの原典回次を照会できるが、原典回次割当が分からなければBLOCKEDにする。
- `FP2-GATES` は未監査/不一致/権利不明・不明な原典IDをFAILまたはBLOCKEDとする。製品問題数は実数とし、固定500件への水増しを禁止。
- `FP2-MERGE` のみが製品JSONを正式に上書きできる。 `FP2-UI` はUI改修を担当するが製品JSONを書き換えない。両者の統合は `FP2-E2E` で行う。
- 同時稼働13セッションに対し、依存待ちのOPEN・BLOCKED・外部CLAIMEDは空きではない。即時実行可能なOPENが尽きたらセッションは終了する。13件を無理に同時着手しない。
- 競合再試行3回でもpushできなければ未取得として停止。管理者は同じ範囲の新規テーマを複製して増やさない。
