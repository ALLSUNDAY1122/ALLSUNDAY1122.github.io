# 保健師｜学びスプリント（iOS）

保健師国家試験の過去問（第108〜112回、546問）を学ぶ専用iPhoneアプリ。

- 無料: 第112回の30問（午前15問＋午後15問）
- 買い切り ¥800（jp.allsunday1122.hokenshisprint.premium.lifetime）で全546問を解放。月額なし・広告なし
- 形式: 4択/5択（正答1つ）・2つ選べ・数値入力（本試験同様に桁ごと入力）
- 図表問題36問は画像つき。学習記録と苦手復習（3回連続正解で卒業）はシリーズ共通仕様

## 構成

- `ios/` — XcodeGen プロジェクト（project.yml）と SwiftUI ソース。`prepare-ios.sh` が
  データ検証とアイコン復元を行い、Codemagic の `hokenshi-sprint-ios` ワークフローから呼ばれる
- `data/` — アプリ同梱用データ（questions-546.json / figures-1.json / figures-2.json）。
  正本はリポジトリの `hokenshi-sprint/data/` と `~/workspace/hokenshi-app/data/`
- アイコンは PNG を Base64 化した `ios/AppIcon1024.png.b64` で保管し、ビルド時に復元する
