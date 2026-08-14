# 辛口レビュー3周｜保健師国家試験｜学びスプリント

基準日: 2026-08-13
正本: 学びスプリント UI要件定義 v2.1 / FP2 v1.4.0 Golden Master
対象: SwiftUI Native実装 + release-ready 330問

## 第1周｜第一印象・導線

### 指摘
1. 初期Nativeシェルは資格名と4タブは分かるが、実データ接続前は「教材を触っている感」が弱かった。
2. 模試が110問単位のみだと本試験の午前/午後感が薄い。
3. 状況設定問題でscenario本文が製品モデルへ渡らないと、問いだけが表示される重大欠陥になる。
4. 結果画面が無いと8問を終えた達成感がなく、Golden Masterの周回感を失う。

### 改善
- 監査済み330問をBundle resourceへ固定し、ホーム数字・分野・履歴を実データ化。
- 模試を `午前55 / 午後55 / 通し110` へ分割。
- `HokenshiDisplayQuestion` でscenario本文を `sourceText` として製品問題へ保持し、状況設定カードとして表示。
- Native結果画面を追加し、正解数・わからない数・復習対象を表示。

### 判定
重大指摘 0。Golden Masterの中心導線は再現。

## 第2周｜アクセシビリティ・誤認防止

### 指摘
1. 選択肢は見た目だけで選択状態を伝えるとVoiceOverで状態が分からない。
2. 一次根拠タイトルを文字だけ表示すると、根拠確認の導線が弱い。
3. 10分野×11問の均等配分を実試験の出題比率と誤認させてはいけない。
4. 文字サイズ設定がUIだけで実画面へ反映されなければ形骸化する。
5. `途中から再開` が問題セット先頭から再開する実装は文言と挙動が不一致。

### 改善
- 選択肢へ `選択中 / 未選択` accessibilityValue と selected trait を追加。
- 解説から一次根拠URLを `Link` で開けるよう変更。
- 模試画面に、均等配分は周回学習用独自設計で実試験比率ではない旨を常時表示。
- 3段階文字サイズを `dynamicTypeSize` へ接続。
- 回答は「次へ」で確定し、確定地点の `currentIndex` と回答payloadを保存。再開は確定済み回答の次から行う。

### 判定
重大指摘 0。誤認・アクセシビリティ・中断復帰の主要欠陥を修正。

## 第3周｜学習品質・安全性・公開品質

### 指摘
1. CIで一時生成した330問だけでは、実アプリへ同じ監査済みbankが入った証拠にならない。
2. 旧2013年保健師活動通知が残ると制度問題の根拠が陳腐化する。
3. 誤答と「わからない」が弱点学習へ結び付かなければ、学びスプリントの価値が落ちる。
4. JSONバックアップを他資格アプリへ誤投入できると状態破損につながる。
5. Privacy Manifestが空だと、UserDefaults利用のrequired reason申告と整合しない。
6. App Store識別情報を命名規則から作るのは正本違反。

### 改善
- canonical→監査→release_ready昇格→Swift Package `Resources/questions.json` 固定をCI化。生成物の同一性も `cmp` で監査。
- 2026-05-15厚生労働省現行通知へのprimary/supplemental再照合をCI化。
- LearningSprintCoreの誤答/unknown→苦手、3連続正解解除をNative製品状態へ接続。
- バックアップは保健師用namespaceで資格跨ぎを拒否。
- PrivacyInfo.xcprivacyにトラッキングなし・収集データなし・UserDefaults `CA92.1` を記録。
- Bundle ID / ASC App ID / Codemagic profile / IAPは識別情報正本に#13がないため未確定のまま保持。推測値をコードへ入れないCIを維持。

### 判定
署名前のソフトウェア/コンテンツ重大指摘 0。

## 残る検証
- Golden Masterの30状態スクリーンショット比較は、署名可能なiOS App targetまたはInternal TestFlight buildができた時点で実施する。
- AppIconはGoogle Drive正本 `13_保健師国家試験.png` を使用し、一覧画像から再生成しない。
- Bundle ID / App Store Connect App ID / Codemagic profile等の識別情報は最上位正本へ登録されるまで推測しない。
- Internal TestFlight実機確認後も、ユーザー明示承認なしにApp Store本審査へ提出しない。
