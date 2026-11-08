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

- FP3正本 `fp3-manabi-sprint/audits/CONTENT_REAUDIT_20261108.md` は2026-11-08第3回追記時点で**180問中20問判定済み（合格17・要修正2・保留1）、未判定160問**。依頼で指定された最初の10問も含む。新規シャード・他セッションの追記は作業開始前に再確認。
- 既判定ID: `2024-04`（合格）、`2024-48`・`2024-53`（要修正）、`2025-26`（合格）、`2026-01`～`2026-15`（合格15件）、`2026-20`（保留）。保留は再判定担当 `FP3-26-HOLD` のみ扱う。既判定に対する解説修正は `FP3-FIX-2` が専任。
- Museが並行担当する `FP3-25-MUSE`/`FP3-26-MUSE` は**既存の外部取得としてCLAIMEDを先行登録**。2025/26の作業番号がまだ完全に確定しないため両年度の他シャードは、Muse成果の確定・完了（DONE）まで依存で保護する。これにより年度内の重複防止を優先。
- FP3の初期認識10件から追加10件が判定済みになっている。監査の合格は制度論点の判定であって原典全選択肢の逐語照合完了ではない。製品ゲートはBLOCKED。
- FP3 AppIcon正本・XcodeGen・Simulatorビルドは既存のCI実績があるが、FP3専用Preflightワークフロー実行は未確認。`FP3-PREFLIGHT` はこの残件だけを調べる。
- FP2公式過去問500問は**検証前の計画目標**。原典の実数、利用条件、学科/実技の回次を確認するまで完成数と断定しない。旧180問は再利用が自動承認されたわけではない。FP2の従前 `CONTENT_BATCH_PLAN.md` の独自600問方針は今回の製品方針と不一致であり、製品へは適用しない。
- FP2旧180問「R1～R3」は仮の回次グループ識別子。実際の原典回次と旧180問の対応・件数を最初に確認し、**IDの昇順で原典回次を並べた第1・第2・第3群**として固定する。180問の実回次数が3でない場合は成果をBLOCKEDにして管理者へ分割修正を要求し、同じ原典回次を複数担当へ割り当てない。回次未確定時の推測による監査は不可。
- FP2学科/実技シャードA/Bは原本台帳で確定する「未収録分」の原典回次・IDを昇順ソートし、連続する前半/後半に分割する（奇数件では前半が1件多い）。旧180問で再利用承認となったIDを除く。原本台帳未確定時は依存未完了として取得しない。

## テーマ一覧

| ID | 対象 | テーマ・排他範囲 | 状態 | 依存（全DONEが必須） | owner | claimed_at | claim_commit | completed_at | evidence / 主な許可出力 |
|---|---|---|---|---|---|---|---|---|---|
| FP3-24-A | FP3 | 2024年度01–20（既判定04を除外）一次資料再監査 | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2024_01_20.md` |
| FP3-24-B | FP3 | 2024年度21–40 一次資料再監査 | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2024_21_40.md` |
| FP3-24-C | FP3 | 2024年度41–60（既判定48・53を除外）一次資料再監査 | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2024_41_60.md` |
| FP3-25-MUSE | FP3 | Muse実行中：2025年度未判定最大20問（既判定26除外、担当IDは成果で確定） | CLAIMED | - | MUSE-EXTERNAL | 外部実行中・取得時刻未確認 | external-unverified | - | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2025.md` |
| FP3-26-MUSE | FP3 | Muse実行中：2026年度未判定最大20問（既判定01–15・20除外、担当IDは成果で確定） | CLAIMED | - | MUSE-EXTERNAL | 外部実行中・取得時刻未確認 | external-unverified | - | `fp3-manabi-sprint/audits/REAUDIT_SHARD_2026.md` |
| FP3-25-A | FP3 | 2025年度01–20のMuse非取得IDを監査 | OPEN | FP3-25-MUSE | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2025_01_20.md` |
| FP3-25-B | FP3 | 2025年度21–40のMuse非取得IDを監査（26既判定） | OPEN | FP3-25-MUSE | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2025_21_40.md` |
| FP3-25-C | FP3 | 2025年度41–60のMuse非取得IDを監査 | OPEN | FP3-25-MUSE | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2025_41_60.md` |
| FP3-26-A | FP3 | 2026年度16–35のMuse非取得IDを監査（20保留の再判定は別作業） | OPEN | FP3-26-MUSE | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2026_16_35.md` |
| FP3-26-B | FP3 | 2026年度36–60のMuse非取得IDを監査 | OPEN | FP3-26-MUSE | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2026_36_60.md` |
| FP3-26-HOLD | FP3 | 2026-20保留の施行日・法令基準日照合と判定 | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_2026_20_HOLD.md` |
| FP3-FIX-2 | FP3 | 2024-48/53の監査済み解説差分を反映（ロック解除承認待ち） | BLOCKED | FP3-24-C | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_EXPLANATION_FIX.md` |
| FP3-PREFLIGHT | FP3 | FP3専用Preflight実行・XcodeGen/Simulator結果記録（既成功と再実行を区別） | OPEN | - | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_PREFLIGHT.md` |
| FP3-CONSOLIDATE | FP3 | 年度シャードを正本へ統合し180問の重複・欠番・判定集計・原典照合ゲート確認 | OPEN | FP3-24-A,FP3-24-B,FP3-24-C,FP3-25-A,FP3-25-B,FP3-25-C,FP3-26-A,FP3-26-B,FP3-26-HOLD,FP3-FIX-2 | - | - | - | - | `fp3-manabi-sprint/audits/parallel/FP3_CONSOLIDATION.md` |
| FP2-SOURCE | FP2 | 公式過去問原本・許諾条件・回次別学科/実技実数台帳（計画500と実数を分離） | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OFFICIAL_SOURCE_LEDGER.md` |
| FP2-OLD-R1 | FP2 | 旧180問の原典回次第1群の再検証（回次別ID・件数確定） | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_01.md` |
| FP2-OLD-R2 | FP2 | 旧180問の原典回次第2群の再検証（回次別ID・件数確定） | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_02.md` |
| FP2-OLD-R3 | FP2 | 旧180問の原典回次第3群の再検証（回次別ID・件数確定） | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_OLD_ROUND_03.md` |
| FP2-ACA-A | FP2 | 公式学科の未収録分：原典台帳順の前半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/academic_part_a.json` |
| FP2-ACA-B | FP2 | 公式学科の未収録分：原典台帳順の後半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/academic_part_b.json` |
| FP2-PRAC-A | FP2 | 公式実技未収録分：原典台帳順の前半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/practical_part_a.json` |
| FP2-PRAC-B | FP2 | 公式実技未収録分：原典台帳順の後半をデータ化 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/batches/official/practical_part_b.json` |
| FP2-GATES | FP2 | 固定500/600前提を廃止し実数・出典対応・重複・権利で判定する検査ゲートを改修 | OPEN | FP2-SOURCE | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_REAL_COUNT_GATES.md` |
| FP2-MERGE | FP2 | 監査合格の公式過去問シャードのみ製品JSONへ統合、A01独自問題除外 | OPEN | FP2-OLD-R1,FP2-OLD-R2,FP2-OLD-R3,FP2-ACA-A,FP2-ACA-B,FP2-PRAC-A,FP2-PRAC-B,FP2-GATES | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_PRODUCT_MERGE.md` |
| FP2-UI | FP2 | FP2製品UIを公式過去問スキーマに移行・暫定モックで画面検証 | OPEN | - | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_UI_MIGRATION.md` |
| FP2-E2E | FP2 | 製品JSON実数・UI・CI・権利表示の最終統合検査 | OPEN | FP2-MERGE,FP2-UI | - | - | - | - | `fp2-manabi-sprint/audits/parallel/FP2_E2E.md` |

## 完了条件と依存上の注意

- 各監査成果は対象ID、原典/法令の一次資料URL、対象基準日、確認範囲、PASS/FAIL/UNVERIFIED相当判定、問題数と未完了件数を残す。取得後に既判定やMuse取得IDを発見した場合はスキップし理由を記載。
- `FP3-25-MUSE`/`FP3-26-MUSE` のDONE化は、該当する外部担当のpush済み成果ファイル・コミットを確認した管理者だけが行う。外部担当のタイムスタンプを捏造しない。
- `FP3-FIX-2` はロック済みデータの編集承認とソースロック解除手順が未確認のため初期BLOCKED。監査記録への差分提案は既存であり、明示許可のない実データ変更は禁止。承認後も対象の解説以外は変更しない。
- `FP3-CONSOLIDATE` は各年度の監査ファイルを集計する。製品ゲート解除は全180問の必要な原典照合・解説反映検証完了と別判定。監査ログの単純集計をリリース承認としない。
- `FP2-SOURCE` は公表物を収集・出典識別子を定義し、正規の使用条件と加工明示を記載。 `FP2-OLD-R*` は先行して旧データの原典回次を照会できるが、原典回次割当が分からなければBLOCKEDにする。
- `FP2-GATES` は未監査/不一致/権利不明・不明な原典IDをFAILまたはBLOCKEDとする。製品問題数は実数とし、固定500件への水増しを禁止。
- `FP2-MERGE` のみが製品JSONを正式に上書きできる。 `FP2-UI` はUI改修を担当するが製品JSONを書き換えない。両者の統合は `FP2-E2E` で行う。
- 同時稼働13セッションに対し、依存待ちのOPEN・BLOCKED・外部CLAIMEDは空きではない。即時実行可能なOPENが尽きたらセッションは終了する。13件を無理に同時着手しない。
- 競合再試行3回でもpushできなければ未取得として停止。管理者は同じ範囲の新規テーマを複製して増やさない。
