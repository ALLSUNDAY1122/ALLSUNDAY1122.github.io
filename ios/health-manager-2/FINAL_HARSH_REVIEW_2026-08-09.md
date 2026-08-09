# 最終辛口レビュー3周｜第二種衛生管理者｜学びスプリント

実施日: 2026-08-09
対象: Web Golden Master v2.1、90問教材、iOS SwiftUI/WKWebView、Codemagic/TestFlight申請パッケージ

## 第1周｜教材品質を疑う

### 辛口指摘
1. 90問あるように見えても、年次有給休暇・BMI等で「数字を変えただけ」の問題が混じれば水増しである。
2. 正答位置が特定番号へ偏れば、知識がなくても位置推測で点が取れ、教材品質が落ちる。
3. 法令問題が古い公表問題の施行日時点のままだと、2026年8月の現行法教材として危険である。

### 改善
- 数値差替え型・高類似候補を、年5日取得義務、比例付与の適用条件、強度率計算、換気回数計算、BMI逆算、クレアチンリン酸等の別能力を問う問題へ再設計。
- 3試験回×3科目の各10問で、正答位置1〜5を各2回に自動均等化。
- `audit-patch-v2.js` / `audit-fixes.js` で基準日、一次確認先、作問由来、権利根拠を付与。
- 2026-08-01施行の産業医関連改正、2025-06-01施行の熱中症対策を現行として反映し、2027/2028施行予定事項は現行法と分離。

### 再監査
- 90問: PASS
- 9セット×10問: PASS
- ID重複: 0
- 高類似0.90以上: 0
- 同一論点の類似警告: 0
- 各セット正答位置1〜5: 各2回
- 水増し重大指摘: 0

## 第2周｜Web版とTestFlight版が本当に同一か疑う

### 辛口指摘
1. Web版だけ修正され、iOS同梱スクリプトが古ければ、Safariで合格してもTestFlightでは旧問題が出る。
2. WKWebViewでサイトを包んだだけでは、iOSアプリとしての価値が弱い。
3. ブラウザのBlobダウンロードだけに頼るJSONバックアップはiOSで不安定になり得る。

### 改善
- `prepare-web-assets.sh` に `audit-fixes.js` と `question-order-v1.js` を追加し、Web公開版とiOS同梱版の教材入力を一致。
- Codemagicで同梱必須ファイルの存在をビルド前に検査。
- SwiftUI/WKWebViewに正解・不正解・ボタン操作のネイティブ触覚フィードバックを追加。
- JSON書き出しをiOSの `UIActivityViewController` 共有シートへブリッジ。
- 教材90問をアプリ内へ同梱し、学習の主要導線はネットワーク不要にした。

### 再監査
- iOS同梱対象に監査修正ファイル: PASS
- Privacy Manifest: あり
- Native JSON share: あり
- Native haptics: あり
- 外部サイト依存の主要教材: なし
- 重大指摘: 0

## 第3周｜申請時に落ちる前提で疑う

### 辛口指摘
1. `submit_to_testflight` の意味を「TestFlightへのアップロード」と誤認すると、Internal Testing OnlyなのにBeta App Review送信を要求する設定になり得る。
2. App Storeキーワードで「過去問」と書くと、独自作問方針と表示が矛盾する。
3. Support/PrivacyやiOS scaffoldが複数箇所にあると、どれが申請正本か分からなくなる。
4. 資格ごとに同じUI基盤を使うため、App Review Guideline 4.3の類似アプリ判定リスクがある。
5. WKWebView主体のため、Guideline 4.2で「Webの再パッケージ」と見なされるリスクを抑える必要がある。

### 改善
- TestFlight Internal Testing Onlyのexport optionを維持し、Codemagicの `submit_to_testflight` はBeta App Reviewを要求しない `false` に修正。App Store本審査自動送信も `false`。
- App Store原稿から「過去問」を削除し「公表回の出題論点に対応した独自問題」と明記。
- Support/Privacyの公開正本を `/health-manager-2/` に一本化し、重複scaffoldを削除。
- Review Notesに第二種固有の試験範囲・90問バンク・9セットを明記。
- 90問完全同梱、8問スプリント、苦手3連続卒業、履歴、中断再開、JSONバックアップ、ネイティブ触覚をアプリ固有の継続価値として明示。
- CodemagicのmacOSビルド前に、共通 `validate_questions.py` を必ず実行するrelease gateを追加。

### 再監査
- TestFlight/Internal設定矛盾: 解消
- App Store表示と教材方針の矛盾: 解消
- 正本重複: 解消
- 4.2対策: 実装・Review Notesへ反映
- 4.3: 技術的な不具合ではなくApp Review固有の残存審査リスクとして記録。第二種固有内容を明確化し、最終提出時に再評価する。
- TestFlight前の重大な修正可能指摘: 0

## 結論

現時点で、AI・機械監査で修正可能な重大指摘は0。次の機械ゲートはCodemagicでのXcodeGen生成、Swift compile、署名、IPA export、App Store Connectアップロード。そこをPASSした後の次の人間品質ゲートはiPhone実機TestFlight確認とする。
