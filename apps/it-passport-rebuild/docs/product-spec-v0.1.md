# Product Spec v0.1

## Goal
IT初心者・非IT職・学生が、短時間でも毎日迷わず学習を進め、3分野の足切りを避けながら総合合格水準へ到達できること。

## Primary users
- 非IT系企業の社会人
- 文系学生・新卒
- IT用語に抵抗がある初学者
- 参考書だけでは継続しにくい受験者

## Competitive position
上位競合は数千問、年度別・分野別、AI質問、復習機能を既に備える。したがって本作は問題数そのものを主訴求にしない。

### Differentiation
1. 毎回「次にやること」が1つだけ明確なホーム
2. 論点単位のmasteryと復習優先度
3. 20秒解説→詳細解説の二段階理解
4. 3分野の足切りリスクを常時可視化
5. 本試験までの残日数と進捗から学習量を調整
6. シラバスversionをデータとして保持し制度改定を差替えで吸収

## Core navigation
### Home
- 今日の10問
- 合格準備度
- 3分野mastery
- 復習待ち件数
- 連続学習日数
- 模試への入口

### Practice
- 1画面1問
- 回答後すぐ正誤
- 20秒解説を最初に表示
- 詳しい解説は展開式
- 選択肢ごとの誤り理由
- 苦手登録は自動、手動お気に入りも可能

### Review
- 間違い
- 正解したが低確信
- 一定期間未復習
- 足切りリスク分野を優先

### Mock exam
- 100問 / 120分
- 3分野構成を本試験に寄せる
- 公式IRT点数は再現できないため、公式点を装わない
- raw正答率・分野正答率・独自の合格安全度を明確に区別する

## Initial diagnostic
15〜20問で3分野を横断。初回で精密な能力推定を装わず、最初の復習順序を作るための粗い診断として扱う。

## Mastery model v0
論点ごとに 0〜100。
- 初回正解 +12
- 初回不正解 -8
- 復習正解 +8
- 連続正解で上限補正
- 経過時間で緩やかに減衰
本番合格点の代替ではなく学習優先度決定用。

## Question schema
- id
- exam_set
- domain
- topic
- stem
- choices[]
- correct_index
- short_explanation
- detailed_explanation
- choice_explanations[]
- origin_type: licensed_official | original
- source_label
- source_url
- syllabus_version
- basis_date
- copyright_note
- difficulty
- tags[]

## Content gates
- 同文重複 0
- 独自作問の高類似 0
- 正解不整合 0
- 解説欠損 0
- 根拠欠損 0
- 出典表示漏れ 0
- syllabus_version欠損 0

## Monetization hypothesis
標準候補は月額200円または買い切り800円。MVPでは課金UIを前面に出さず、中心学習体験の価値を先に検証する。

## Non-goals for v0
- 生成AIチャット常時接続
- アカウント必須化
- SNS機能
- ランキング
- 過剰なゲーム演出
- 公式IRTスコアの模倣
