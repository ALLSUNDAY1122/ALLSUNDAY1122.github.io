# HM2 Build 24 — オーナー判断によるApp Review申請と未解消事項

記録日: 2026-11-22（JST）
承認: オーナーが16:20 JSTに「本番申請して」と明示し、次の未解消リスクを認識した上で申請を指示（本会話で再確認）。
対象アプリ: 第二種衛生管理者｜学びスプリント (App ID 6799751657; bundle jp.allsunday1122.healthmanager2)
対象バージョン・ビルド: 1.0 (Build 24)
Apple Build ID: 193141f5-4144-4843-a71c-05419d4aa735
Codemagicビルド元SHA: 485d934f3fab79747ee446d947f1bbe21dcafd20
問題バンクSHA-256: e5061112c8ab6073dc40063b736cfa77b2ee93f57cfe82cdbedcd8098aadc6da

## 確認できた事実
- App Store Connect Build 24: VALID、APP_STORE_ELIGIBLE、expired=false、TestFlight internal group sunの一覧に存在。
- App Store Connect v1.0へのBuild 24紐付けは個別readbackで確認。
- ASC evidence: automation/asc-results/hm2-b24-asc-readback-20261122-r1.json / hm2-b24-asc-attached-readback-20261122-r2.json
- 正本候補: automation/asc-results/hm2-verified-release-candidate.json。ただしdevice_test_pass/iap_review_pass/app_privacy_verifiedはfalse（未確認）。現行の厳格申請ゲートはPASSではない。

## 未解消のままの事項（PASSにしない）
1. CLAUDE_300_ID_COMMIT_CSV_NOT_IMPORTED — 正本CSVがなく、指定SHA-256の実体未確認。
2. ACTUAL_APP_SCREENSHOTS_NOT_STORED — 現行バンクに紐づくシミュレーター実画像とmanifestの保存未確認。
3. CURRENT_BUILD_ASC_EVIDENCE_INVALID — ASCのBuild 24 VALID自体は照合済みだが、ゲートが要求する実機・IAP・App Privacyの個別確認が未了。
4. 実機動作検証 — 未確認。
5. IAPメタデータ・購入／復元・審査用確認 — 未確認。
6. App Privacyの現行ASC登録状態 — 未確認。

## 方針・責任分界
- オーナーは上記を既知のリスクとして受容し、Build 24でApple App Reviewへの提出を明示的に指示。
- 上記の検証済み／PASSへの書換え、証拠捏造、品質ゲートの緩和は行わない。
- 既存のApple側提出前検査・Appleの必須要件によって拒否される可能性は保持し、拒否時はそのまま記録する。
- 既存の汎用最終提出ワークフローによって、対象アプリ・バージョン・Buildを厳密照合して送信する。
- この文書の記載は「品質保証の承認」ではなく「品質未確認のまま申請するオーナー判断の記録」である。
