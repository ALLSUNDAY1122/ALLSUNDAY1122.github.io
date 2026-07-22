# 地方調査セッション共通プロンプト v4.0

この文書は、`operations/session-split-policy.json`で定義された8地方セッションの正式な共通プロンプトです。自治体比較プロジェクト運用憲章v2.1と併用し、矛盾時はユーザーの最新指示、GitHub上の現在状態、本プロンプトの順に優先します。

## 1. セッションID

開始時にユーザーが指定した`sessionId`を固定し、次を読みます。

- `operations/municipality-assignment-policy.json`
- `operations/session-split-policy.json`
- `operations/control/session-checkpoints/{sessionId}.json`
- 自セッションの親地方ブランチ、task、自治体JSON、作業ブランチ、PR、CI

セッションIDが指定されていない場合は新規自治体へ着手せず、A/Bのどちらかを確認します。

## 2. 担当範囲

- 新規自治体は、自セッションの`prefectureCodes`内だけから選びます。
- `task.assignedTeam`にはA/Bを付けず、`parentTeam`を保存します。
- 分割時点で作業中の自治体はAセッションが完了まで引き継ぎます。
- 自セッション外の自治体は編集しません。
- A/Bは同じ親地方統合ブランチを使います。地方統合ブランチを8本へ増やしません。

## 3. 「次」の処理

人間は原則として「次」とだけ入力します。「次」を受けたら、説明だけで終了せず、次の順序で安全に連続実行します。

1. 自checkpointの作業中自治体を最優先で復元する。
2. 対象自治体のtask、JSON、同名ブランチ、オープンPRを再検索し、重複作成を防ぐ。
3. 作業中案件がなければ、自セッション範囲の未登録・未着手自治体を自治体コード昇順で選ぶ。
4. 親地方統合ブランチの最新コミットから`data/{自治体コード}-{自治体名英数字表記}`を作る。
5. 必須9制度を自治体公式情報から調査し、自治体JSONとtaskへ保存する。
6. 検証し、PRのbaseを親地方統合ブランチに固定する。
7. CI成功、競合なし、差分が対象自治体と自checkpointだけであることを確認して地方統合する。
8. taskを`merged`へ更新し、自checkpointへ完了自治体、PR、CI、次候補を保存する。
9. 時間と安全性が許す限り次自治体へ進み、少なくとも1自治体の地方統合完了を目標とする。

公式根拠が不足する制度は推測で埋めません。`needs_medium_review`、`needs_coordinator`または`blocked`を使い、理由と確認済み範囲をtaskとcheckpointへ保存して、同じ自治体で無限試行しません。

## 4. 競合防止

地方セッションが通常編集してよいのは次だけです。

- 対象自治体JSON
- 対象自治体task
- `operations/control/session-checkpoints/{sessionId}.json`

次は全国統括だけが編集します。

- `operations/control/global-state.json`
- `operations/control/release-queue.json`
- `operations/control/regions/*.json`
- `operations/control/audit-log.jsonl`
- `data/generated/municipalities.json`
- `operations/progress.json`
- 共通定義、生成処理、公開画面

親地方でA/B合計10自治体に達したかの判定と全国統合は全国統括が行います。

## 5. チェックポイント

自checkpointは次のタイミングで必ず更新します。

- 新規自治体を選定したとき
- 作業ブランチを作成したとき
- PRを作成したとき
- CI結果が確定したとき
- 地方統合したとき
- 保留または例外が発生したとき

会話履歴ではなくGitHub上のcheckpointを現在地の正本とします。新セッションは過去会話を長く読み直さず、checkpointとGitHub実状態から直ちに再開します。

## 6. 呼出間隔と報告

- A/Bを交互に動かし、各セッションへの「次」の間隔は従来の2倍を標準とします。
- 途中ログ全文は会話へ貼らず、GitHubへ保存します。
- 会話上の最終報告は、完了自治体、PR・CI、親地方の繰越数、自checkpointの次自治体、問題の有無だけにします。

