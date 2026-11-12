# 第一種衛生管理者 OpenStax 参照問題の表現権利監査・書換案（2026-11-12）

## 位置づけ
- 対象ブランチ：`codex/hm1-integrate-basic-a-b-c-20261111`。参照した14件の既存5肢監査JSONからOpenStaxが登録・検証先に現れる問題をIDで抽出。
- 先行報告の**18件とは固有参照章URLの件数**（`/sites/books/`を`/books/`へ正規化した章URL）であり、**問題数ではない**。実際には **27問題、正規化後18章URL**。旧版`anatomy-and-physiology`の1章はCC BY 4.0、残る17章は現行書籍名からCC BY-NC-SA 4.0。版差とサイトの追記注意書きは継続精査。
- 規約：Anatomy and Physiology 2e https://openstax.org/books/anatomy-and-physiology-2e/pages/preface 、Biology 2e https://openstax.org/books/biology-2e/pages/preface 、Fundamentals of Nursing https://openstax.org/books/fundamentals-nursing/pages/preface はCC BY-NC-SA。旧Anatomy and Physiology https://openstax.org/books/anatomy-and-physiology/pages/preface はCC BYの案内（ただし同ページ内の汎用reuse文面に矛盾する非商用記載もあり、実際に転載するなら権利者に最新版条件を照会）。商用利用規約 https://help.openstax.org/s/article/Commercial-use-under-the-Creative-Commons-License 。
- **監査証拠の限界**：対象の現行「問題文・全5肢」は既存監査JSONから確認したが、同JSONには**解説`detail`の全文が収録されていない**。また原典英語本文は22.3/25.6/14.1/Fundamentals 7.1の代表章を直接閲覧したのみで、残章の全文対照・過去の作成履歴・翻訳元の照合は未実施。ゆえにどの設問についても「転載なし／翻案なし」を法的に最終断定しない。独創的な事例・数値・誤答構成は見られるがそれ単独では権利クリアにならない。
- **区分**：要優先照合=定義・列挙・定型計算・経路等で原典の構成への依存が疑われ、翻案の可能性を積極的に潰すべきもの（**違反認定ではない**）。通常照合=事例設定や対比に一定の独立性が見られるが、英文との逐語・翻訳比較および解説の確認が必要。

## 27問 個別台帳
| 問題ID | 書籍のライセンス | 内容・中心命題 | 表現リスク暫定 | 原典との照合・次の措置 |
|---|---|---|---|---|
| `2026-04-Q35` | CC BY-NC-SA | 耳石器と半規管の負荷比較 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `2026-04-Q36` | CC BY-NC-SA | 胆汁酸欠乏と膵リパーゼ欠乏の比較 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `2026-04-Q37` | CC BY-NC-SA | 後根神経節と後索の障害部位 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `2026-04-Q38` | CC BY-NC-SA | 肝尿素回路と腎排泄の機序 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `2026-04-Q39` | CC BY-NC-SA | 高血糖性尿糖とアルブミン尿 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `2025-10-Q35` | CC BY-NC-SA | 高血糖性尿糖と腎性尿糖 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `2025-10-Q36` | CC BY-NC-SA | 肺循環とガス交換障害 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `undefined` | CC BY-NC-SA | 要確認 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `undefined` | CC BY-NC-SA | 要確認 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `undefined` | CC BY-NC-SA | 要確認 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `undefined` | CC BY-NC-SA | 要確認 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `2025-04-Q41` | CC BY-NC-SA | ATPとクレアチンリン酸 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-B-Q31` | CC BY-NC-SA | QRSと触知脈拍の差 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-B-Q32` | CC BY（旧版、要条件確認） | 右下肢リンパの胸管経路 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-B-Q34` | CC BY-NC-SA | 横隔膜と外肋間筋の寄与 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-B-Q35` | CC BY-NC-SA | 吸気相の肺胞内圧変化 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q36` | CC BY-NC-SA | 安静呼息と努力性呼息 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q37` | CC BY-NC-SA | 毎分換気量の計算 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q38` | CC BY-NC-SA | 肺活量の計算 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q39` | CC BY-NC-SA | 橋・延髄の呼吸調節 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-B-Q42` | CC BY-NC-SA | ネフロンとADHの関係 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q43` | CC BY-NC-SA | 血流と濾液の経路 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-B-Q44` | CC BY-NC-SA | 糖再吸収飽和と尿細管分泌 | 要優先照合 | 原典の定義・順序・数値構成との一致を精査し、下記の独自設計案を適用候補とする |
| `practice-C-Q38` | CC BY-NC-SA | 中枢・末梢神経の分類 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-C-Q40` | CC BY-NC-SA | 消化管の神経・ホルモン調節 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-C-Q42` | CC BY-NC-SA | 小脳と半規管の機能分担 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |
| `practice-C-Q43` | CC BY-NC-SA | 中心前回病変と対側運動障害 | 通常照合 | 事例・肢の表現には独立要素があるが原典翻訳類似・解説全文は未確認 |

## 正規化したOpenStax出典18章（書籍版別）
1. https://openstax.org/books/anatomy-and-physiology-2e/pages/10-3-muscle-fiber-contraction-and-relaxation — CC BY-NC-SA — 対応ID：2025-04-Q41
2. https://openstax.org/books/anatomy-and-physiology-2e/pages/12-1-basic-structure-and-function-of-the-nervous-system — CC BY-NC-SA — 対応ID：
3. https://openstax.org/books/anatomy-and-physiology-2e/pages/13-4-the-peripheral-nervous-system — CC BY-NC-SA — 対応ID：practice-C-Q38
4. https://openstax.org/books/anatomy-and-physiology-2e/pages/14-1-sensory-perception — CC BY-NC-SA — 対応ID：2026-04-Q35
5. https://openstax.org/books/anatomy-and-physiology-2e/pages/14-2-central-processing — CC BY-NC-SA — 対応ID：2026-04-Q37
6. https://openstax.org/books/anatomy-and-physiology-2e/pages/14-3-motor-responses — CC BY-NC-SA — 対応ID：practice-C-Q43
7. https://openstax.org/books/anatomy-and-physiology-2e/pages/16-5-the-coordination-and-gait-exams — CC BY-NC-SA — 対応ID：practice-C-Q42
8. https://openstax.org/books/anatomy-and-physiology-2e/pages/17-4-the-thyroid-gland — CC BY-NC-SA — 対応ID：
9. https://openstax.org/books/anatomy-and-physiology-2e/pages/20-5-circulatory-pathways — CC BY-NC-SA — 対応ID：2025-10-Q36
10. https://openstax.org/books/anatomy-and-physiology-2e/pages/22-3-the-process-of-breathing — CC BY-NC-SA — 対応ID：practice-B-Q34、practice-B-Q35、practice-B-Q36、practice-B-Q37、practice-B-Q38、practice-B-Q39
11. https://openstax.org/books/anatomy-and-physiology-2e/pages/23-1-overview-of-the-digestive-system — CC BY-NC-SA — 対応ID：practice-C-Q40
12. https://openstax.org/books/anatomy-and-physiology-2e/pages/23-7-chemical-digestion-and-absorption-a-closer-look — CC BY-NC-SA — 対応ID：2026-04-Q36、
13. https://openstax.org/books/anatomy-and-physiology-2e/pages/24-2-carbohydrate-metabolism — CC BY-NC-SA — 対応ID：
14. https://openstax.org/books/anatomy-and-physiology-2e/pages/24-4-protein-metabolism — CC BY-NC-SA — 対応ID：2026-04-Q38
15. https://openstax.org/books/anatomy-and-physiology-2e/pages/25-6-tubular-reabsorption — CC BY-NC-SA — 対応ID：2026-04-Q39、2025-10-Q35、practice-B-Q42、practice-B-Q44
16. https://openstax.org/books/anatomy-and-physiology/pages/21-1-anatomy-of-the-lymphatic-and-immune-systems — 旧版CC BY（転載時再確認） — 対応ID：practice-B-Q32
17. https://openstax.org/books/biology-2e/pages/41-2-the-kidneys-and-osmoregulatory-organs — CC BY-NC-SA — 対応ID：practice-B-Q43
18. https://openstax.org/books/fundamentals-nursing/pages/7-1-indicators-of-physiologic-functioning — CC BY-NC-SA — 対応ID：practice-B-Q31

## 書換案（要優先照合から6問を具体化、**未適用**）
いずれも元の問題文や原典の語順を換言するだけでなく、判断条件・誤答構成・解説の論理を独立に再設計する提案。現時点の独立知見から起案し、採用前に別の利用可能な公的・学術一次資料で5肢を検証すること。**これらの文案の存在をもって商用権利CLEARとはしない**。

### `practice-B-Q35`（吸気時圧差）
- 新設問：『呼吸測定中、気道閉塞のない被験者で、吸息中盤には空気が気管を肺の方向へ流れていたが、吸息の終わりに一瞬だけ気流量が0になった。呼吸運動が続く前提で、この二時点における肺胞内圧の変化として最も合理的なのはどれか。』
- 新5肢：①両時点とも大気より高圧／②中盤は大気より低圧、気流0時は大気とほぼ等圧／③中盤は等圧で気流0時は高圧／④中盤は高圧で気流0時は低圧／⑤気流の向きと圧差は無関係。
- 正答案：②。新解説案：肺への気流は気道抵抗を介した大気と肺胞間の圧差に従う。流入中は肺胞側が低圧で、気流が停止した瞬間には両圧は概ね釣り合う。肺容量が増えていても圧差が恒常的に持続するとは限らない。

### `practice-B-Q36`（努力性呼息）
- 新設問：『安静呼吸では支障のない人が、短時間に勢いよく息を吐く際だけ腹部の筋収縮を意識した。安静呼息と努力性呼息の機序の違いについて適切なのはどれか。』
- 新5肢：①安静呼息は常に腹筋の最大収縮を要する／②努力性呼息中は肺胞圧が大気より低くなる／③安静呼息は主に弾性復元、努力性では腹筋等の活動が加わる／④呼息は横隔膜の収縮のみに依存する／⑤努力性呼息で腹筋は胸郭内圧に作用しない。
- 正答案：③。新解説案：通常の安静呼息は主として吸息筋の活動低下と呼吸器系の弾性復元による。呼息を強める際には腹筋等の呼息筋が加わって胸腔内圧の調節に寄与する。空気が外向きに流れる間の肺胞圧は原則として大気圧より高い。

### `practice-B-Q37`（換気量）
- 新設問：『ある測定時間30秒間に安定した呼吸が9回あり、1回に出入りした空気量を0.45Lと評価した。同じ呼吸条件が1分続くと仮定した場合の分時換気量はどれか。』
- 新5肢：①4.05L/分／②8.1L/分／③9.0L/分／④18L/分／⑤0.45L/分。
- 正答案：②。新解説案：30秒に9回なら60秒換算18回。0.45L×18=8.1L/分。これは分時換気量の計算であり、死腔換気を除いた肺胞換気量とは異なる。

### `practice-B-Q38`（肺活量）
- 新設問：『呼吸機能の簡易記録で一回換気量0.6L、予備吸気量2.2L、予備呼気量1.1L、残気量1.4Lと得た。肺活量として算入すべき値はどれか。』
- 新5肢：①2.8L／②3.3L／③3.9L／④5.3L／⑤1.4L。
- 正答案：③。新解説案：肺活量は一回換気量・予備吸気量・予備呼気量の合計。残気量は肺活量に含めないので0.6+2.2+1.1=3.9L。全肺気量とは区別する。

### `practice-B-Q43`（血液と濾液の分岐）
- 新設問：『糸球体から出た血液が周囲の毛細血管へ向かうのと同時に、濾過液はボーマン嚢から尿細管へ入る。血液と濾液の最初の分岐を正しく説明する組合せはどれか。』
- 新5肢：①血液は輸出細動脈、濾液は尿細管へ／②血液はボーマン嚢、濾液は輸出細動脈へ／③血液は集合管、濾液は輸入細動脈へ／④血液・濾液とも尿細管周囲毛細血管へ／⑤血液・濾液とも輸出細動脈へ。
- 正答案：①。新解説案：糸球体から血液は輸出細動脈を介して血管系を進むが、濾液はボーマン嚢腔に入り尿細管へ移る。血管内経路と尿路の混同を避ける。

### `practice-B-Q44`（再吸収と分泌）
- 新設問：『血糖の上昇で腎尿細管のブドウ糖回収能力を超える負荷が生じた。一方、別の溶質は血管側から尿細管の内腔へ移動した。この二つの現象について適切なのはどれか。』
- 新5肢：①ブドウ糖回収の上限超過は尿糖の一因となり、血液側から内腔への輸送は分泌に当たる／②ブドウ糖回収に限界はない／③内腔への分泌は再吸収と同じ方向の現象である／④尿糖が出れば糸球体濾過は必ず停止する／⑤尿細管では物質移動が一方向にしか起きない。
- 正答案：①。新解説案：濾過されたブドウ糖は通常近位尿細管で再吸収されるが、輸送能力を超えた分は尿に現れ得る。血管から尿細管内へ向かう輸送は分泌、逆向きは再吸収である。

### その他の優先照合6問（具体案の着眼点）
- `2026-04-Q35`：患者の頭位傾斜と回転停止直後を比較する二条件問題へ組替え。原典の「受容器の一覧表」を模倣しない。
- `2026-04-Q36`：胆汁流出障害と膵外分泌障害の症例から分解・ミセル化の順序を判断する条件問題へ組替え。原典の消化手順を連続翻訳しない。
- `2026-04-Q39`：血糖値・尿糖・アルブミン尿の別指標を組み合わせる診断の限界を問う。原典表の項目配列を利用しない。
- `2025-10-Q35`：血糖正常の腎性糖尿と高血糖の比較を、具体的検査数値付きの臨床検査判断に改める。
- `2025-10-Q38`：胃酸抑制下のペプシノーゲンと膵トリプシノーゲンについて、二者の活性化箇所を図表なしの条件問題に改める。
- `practice-B-Q42`：ネフロンの全経路暗唱を避け、脱水時の集合管透過性変化のみを切り出す。

## リリースに必要な次の証跡
1. 現行264問の**生成済みJSON全量**から27問の`stem`、`choices`、`detail`、`key`、出典リンクを同一版で採取し、監査JSONにある文面との差を確定する（今回の監査ファイルでは解説全文が欠落）。
2. 当該18章のOpenStax英語原文と日本語問題・解説の**意味構成／事例／表・図／具体的数値の由来**を別々に照合。原典文章の機械翻訳・要約翻案疑いが残るものは書換後も再監査。
3. 6案は**提案のみ、配布データ反映なし**。採用する場合は正答位置維持・再生成264問限定差分・1,320肢検査・出典独立追証を必須とする。
4. 商用アプリが直接OpenStax文面・図表・翻訳に依存する場合は権利許諾または権利クリアな別資料への置換が必要。**現時点で表現権利CLEARは0問**（未確認扱い）、公開ゲートBLOCKED維持。
