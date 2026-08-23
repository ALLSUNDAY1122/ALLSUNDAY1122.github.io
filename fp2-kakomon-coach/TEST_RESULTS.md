# TEST_RESULTS.md（実施した試験と結果）

作成日: 2026-08-02

## 確認レベルの凡例（ユーザー指示の定義に基づく）
- A：構文確認
- B：自動テスト
- C：PCブラウザ実操作
- D：HTTPS試用URL実操作
- E：iPhone Safari確認
- F：TestFlight確認

## 実施状況まとめ

| レベル | 実施有無 | 内容 |
|---|---|---|
| A：構文確認 | **実施済み** | `node --check`によるJS構文チェック合格 |
| B：自動テスト | **実施済み** | Node.jsによるセッション抽出・弱点ロジック・データ整合性の自動テスト（全19アサーション合格） |
| C：PCブラウザ実操作 | **未実施** | 本セッションはCLI/ヘッドレス環境であり、GUIブラウザを操作する手段がなかった |
| D：HTTPS試用URL実操作 | **未実施** | 公開URLが存在しないため実施不可 |
| E：iPhone Safari確認 | **未実施** | 実機を保有・操作する手段がないため実施不可 |
| F：TestFlight確認 | **未実施** | ネイティブビルド自体が今回のスコープ外のため実施不可 |

**重要：C・D・E・Fは実施していない。** 「確認済み」と偽ることはしていない。次工程（人間またはCodex）による実機・実ブラウザでの確認を強く推奨する。

## レベルA：構文確認の詳細

実行コマンド：
```
node --check scripts/_check(生成物)/js_block.js
```
（`FP2_KAKOMON_COACH_v1.0.0.html`内の`<script>`部分をPythonで抽出し、Node.jsの`--check`オプションで構文検証）

結果：
```
JS SYNTAX OK
```

追加確認：埋め込みJSONデータ（`<script id="questionData" type="application/json">`）をPythonの`json.load`でパースし、件数が180件であることを確認済み。

```
embedded question count: 180
```

## レベルB：自動テストの詳細

実行コマンド：
```
node scripts/tests/algo_test.js
```

このテストは、アプリ本体（`FP2_KAKOMON_COACH_v1.0.0.html`）に実装した以下のアルゴリズムを**同一のロジックをそのまま抽出したコード**で検証したものである（DOM操作を除く純粋ロジックの単体テスト）。

実施した検証項目と結果（すべてPASS）：
1. 総問題数が180問であること
2. 年度別セッション（2026-05／2025-05／2025-01）がそれぞれ60問であること
3. 分野別セッション（6分野）がそれぞれ30問であること
4. 「今日の10問」初回抽出が10問・重複なし・分野バランス（各分野最大2問）であること
5. 「今日の10問」2回目抽出が、未出題問題を優先し、170問の未出題が残っている状況で1回目と重複しないこと
6. 誤答時に弱点登録され連続正解数が0になること
7. 正解を重ねると連続正解数が1→2→3と増加し、3で弱点解除（登録から削除）されること
8. 連続正解の途中で誤答すると連続正解数が0にリセットされること
9. 埋め込み済み180問すべてが、id/question/choices（4件）/answer（1〜4）/explanation（10文字超）を備えていること

実行結果（抜粋、全19件PASS）：
```
PASS: total questions === 180 (actual 180)
PASS: exam 2026-05 has 60 questions (actual 60)
PASS: exam 2025-05 has 60 questions (actual 60)
PASS: exam 2025-01 has 60 questions (actual 60)
PASS: domain ライフプランニングと資金計画 has 30 questions (actual 30)
PASS: domain リスク管理 has 30 questions (actual 30)
PASS: domain 金融資産運用 has 30 questions (actual 30)
PASS: domain タックスプランニング has 30 questions (actual 30)
PASS: domain 不動産 has 30 questions (actual 30)
PASS: domain 相続・事業承継 has 30 questions (actual 30)
PASS: first today-10 run returns 10 questions (actual 10)
PASS: first today-10 run has no duplicate questions
PASS: first today-10 run is domain-balanced (max per domain <=2, actual max 2)
PASS: second today-10 run (unseen-priority) does not repeat the first 10 when 170 unseen remain (overlap=0)
PASS: wrong answer registers weak with streak 0
PASS: 1st correct after wrong -> streak 1, still weak
PASS: 2nd correct -> streak 2, still weak
PASS: 3rd consecutive correct clears weak status
PASS: wrong answer mid-streak resets streak to 0
PASS: all embedded questions have valid id/question/choices/answer/explanation (missing: 0)
```

## レベルB補足：DOMスモークテスト

Node.js上に最小限のfake DOM（`document.getElementById`, `querySelector`等のスタブ）を用意し、アプリのJSコード全体（IIFE）を`vm.runInThisContext`で実行して、初期表示処理（`go("home")`実行を含む）が例外を投げずに完走することを確認した（`scripts/tests/dom_smoke_test.js`）。

結果：
```
Script executed without throwing.
```

これは「実ブラウザでの表示確認」の代替ではなく、あくまで「DOMアクセスがあってもスクリプト全体がクラッシュしない」ことを確認する簡易チェックである。

## レベルB補足：ダミーボタンの静的検査

正規表現で、HTML生成コード中の`data-action`属性値・`id`属性値をすべて抽出し、対応する`querySelector`/`getElementById`によるイベントバインドが存在するかを検査した。

結果：
```
data-action values: {start-weak, start-today, start-year, start-domain, review-weak}
data-tab values: {}（動的生成のため文字列リテラルでは検出されないが、bindTabbar()内でgetAttribute("data-tab")により処理されることをコードレビューで確認済み）
ids in templates: {homeBtn, dontknowBtn, choices, nextBtn, resetBtn, quitBtn}
Unbound: [('id', 'choices')]  ← "choices"は選択肢を格納するコンテナdivのidであり、それ自体はボタンではないため問題なし
```
すべての操作可能なボタン・要素にイベントハンドラが結線されていることを確認した。ダミーボタン・無反応ボタンは存在しない。

## 未実施項目に関する注記

C（PCブラウザ実操作）・D（HTTPS試用URL）・E（iPhone Safari）・F（TestFlight）は、本セッションの実行環境（CLIベースのサンドボックス）では実施不可能だった。特にiPhone実機での横スクロール有無、タップ反応性、文字サイズ変更時のレイアウト崩れ等は、次工程での実機確認が必須である。CSS設計上は横スクロールが発生しないよう配慮した（`max-width:520px`のコンテナ幅、`word-break:break-word`の適用等）が、これは設計上の配慮であり実機での保証ではない。
