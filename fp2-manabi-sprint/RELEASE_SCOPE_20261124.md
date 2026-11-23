# FP2 初回リリース範囲・正式ゲート（2026-11-23）

期限: 2026-11-24 08:00 JST。今回の目標: SUBMISSION_READY / WAITING_FINAL_APPROVAL。App Reviewへの提出は禁止。

## 参照したNotion正本（取得済み）
- 共通フロー v2.8 https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 申請手順 https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
- 学びスプリント専用Skill v1.0 https://app.notion.com/p/40e09c10697d81969bcee2ec627c97e9
- UI Master v2.1 https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 問題生成・監査ループ v1.0 https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- 分割セッション v1.1 https://app.notion.com/p/3bd09c10697d81cab637c02d1f00d22d

## 暫定MVP
学科6分野各20問、計120問を最大目標。四肢択一・正答一意・各肢理由・根拠URL・適用法令基準日を必須とする。独立監査済みだけ採用。60問への縮小は監査PASS・公式出題範囲・学習価値の評価後のみ。模試は公式本試験の再現でない場合『オリジナル演習』と明記。実技・課金・AI機能・600問拡張は対象外。公式問題の利用条件を確認できない場合は公式シラバス・一次資料から独自作問。旧180行のDrive台帳は2026-09-16時点の証跡であり、現在のcanonical実装・独立監査PASSの証拠とみなさない。

## 正式品質ゲート（Skill v1.0）
- Q0 根拠・要件確定: 公式要綱、試験範囲、年度、法令基準日、二次利用条件
- Q1 教材・問題品質: canonical統合後の件数/ID/高類似/欠損検査と、各肢・正答・解説の独立原典監査
- Q2 学習価値: 回答・即時採点・ここだけ覚える・解説・弱点復習の循環
- Q3 製品体験: UI Master v2.1 Golden Master、オフライン、Safe Area、アクセシビリティ、履歴保持・復帰
- Q4 独立レビュー・実利用確認: 別レビュー担当者と受験生に近いユーザビリティ確認。未実施はNOT TESTED
- Q5 品質判定・引渡し: Critical/High解消、canonicalと組込bank一致、全証跡と変更履歴
各ゲートはPASS/FAIL/BLOCKED/NOT TESTED。重大欠陥は他のPASSで相殺不可。

## 提出準備ゲート（v2.8 / 申請手順）
- GitHub PR/CI、テスト・lint・構文・データ検査、資産同梱とhash一致
- Bundle ID / App ID / Version / Build番号、署名・配布経路、iOS実ビルド検証
- TestFlight実機確認、オフラインと学習記録の再起動確認
- App Store Connectの画像、原稿、権利、プライバシー、年齢、輸出、URLを実装と照合
- RELEASE_STATUS.md, RELEASE_CHECKLIST.md, CODEX_HANDOFF.md, APP_STORE_METADATA*.md, release-status.jsonを更新
- すべてPASSの場合に限り SUBMISSION_READY / WAITING_FINAL_APPROVAL。Add for Review / Submit for Review は実行しない

## 並列運用
現時点では複数Workerを起動していない。並行時はHQ+最大2 Worker、担当ごと専用branchとwrite ownership、同一green baseline、短いWave、統合後の再監査を必須とする。

## 現在の実測
GitHub上の旧 UI index.html は存在。2026-09-16 PRODUCTS_DATA_STATUSでは8問サンプルと記録。実最新の問題数、正本bank、UI組込、Q0-Q5、iOSビルド、ASCは未検証。提出可能状態への遷移は禁止。
