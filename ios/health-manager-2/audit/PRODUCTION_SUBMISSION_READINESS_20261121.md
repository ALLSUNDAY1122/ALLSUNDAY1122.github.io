# 第二種衛生管理者｜App Store本番申請の準備判定（2026-11-21 JST）

**結論：申請不可（BLOCKED）／申請準備を実施済み。** 品質ゲートは緩和していない。実際の `Submit for Review` は実施していない。

## 正本の識別
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Branch: `audit/hm2-quality-20261110`
- App Store Connect App ID: `6799751657`
- Bundle ID: `jp.allsunday1122.healthmanager2`
- Version: `1.0.0`／App Store Version: `1.0`
- 最新監査対象300問JSON SHA-256: `8540991f1a75a9eaa640d695fe7ee1c54dc57861141c5d19514f43311f455fb0`
- 開発対象は**iPhone専用**：`project.yml`の`TARGETED_DEVICE_FAMILY: "1"`。新ビルドの実際のサポート対象はApple側のビルド情報で再確認する。iPad対応ビルドであれば13インチスクリーンショットが必要。

## 今回の実装・検証
1. **StoreKit 2**：価格固定表示（`¥200/月`／`¥800`）を廃止し、取得したAppleの商品`Product.displayPrice`をローカライズ表示する。月額商品は自動更新・1か月期間を検証。不取得時は「価格を取得中」と表示し購入できない。実機課金試験は未実施。
2. **申請前の安全検査**：`scripts/hm2_submission_readiness.py`を追加。300問の5肢・ID一意性、新SHA一致、正式178問スコープ、Privacy Manifest、価格表示、生成元からのJSONバイト一致、元の厳格エクスポータ結果を確認。証跡が欠ければ申請を拒否する。既存`HM2_RELEASE_REVIEW_BLOCKED`はそのまま。
3. **読み取り専用CI**：`.github/workflows/hm2-production-readiness.yml`。2026-11-21 実行 [44877354001](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/44877354001) は処理成功。**技術エラー0、submission_ready=false**。ワークフローの成功は本番申請の合格を表さない。
4. **旧申請ルートの保護**：`.github/workflows/app2-006-hm2-submit-review.yml`に本番申請前の厳格ゲートを追加。2026年9月の旧Build 22を無条件に再利用しないよう、申請対象ビルドと最新承認候補の照合を追加。**旧ワークフローのBuild 22固定指定は残るため、新ビルド確定後に人の承認を得て更新が必要**。対象ブランチの変更をmainに反映する前にはコードレビュー必須。
5. **実アプリ画面検証用CI**：`.github/workflows/hm2-audit-simulator-review.yml`。iPhone Simulator上のSwiftUI/WKWebViewアプリとUIテストを実行する。撮影はDEBUG限定の価格モックが混じる暫定証跡であり、Apple実価格の照合前に正式ストア画像として扱わない。アプリデータやApp Store Connectの変更なし。

## GitHub Actionsで確認したブロッカー（2026-11-21）
| 区分 | 状態 | 正しい解消条件 |
|---|---|---|
| 178問の独立専門家承認 | BLOCKED | 新SHA版の逐肢5択・一次資料・法令版の判断と実名承認を各IDで証跡化。現在0/178 |
| 300問の出典・権利の最終判断 | BLOCKED | 個別ライセンス／原著作物の取り扱い等を確認し、承認記録を保存。資料URLがあるだけでは合格不可 |
| 全300問の最終変更コミットCSV | 取込保留 | Claude側で保管、SHA-256 `a4404d36387f13c39ad13d06f30a437f78f4f5c763ddb1d5c2b31570fc5aed19`。**ユーザーのリポジトリ追加承認後**、受領した実CSVのSHA・全300IDを独立照合。推定で再生成しない |
| 新ビルドとASC現況 | 未確認 | 上記SHAを包含する新署名ビルドをCodemagicで作成。AppleのVALID・非期限切れ・対象Version紐付け・Internal TestFlight・実機・IAP確認をread-back |
| App Store画面キャプチャ | 現行ビルド分未確定 | **実アプリのiPhone Simulator/実機撮影**、ハッシュ保存、App Store Connect上の新ビルドとの表現一致、価格照合 |
| App Privacy / IAP / 年齢評価 | 最終read-back未確認 | 現行設定・日本向け課金価格と商品ステータス・審査情報・プライバシー申告・年齢評価をASCから独立照合 |
| 人間の最終提出許可 | 未受領 | 上記PASS後に対象App/Version/Build/商品を固定してユーザーが最終承認する |

## 履歴の取り違え防止
- Apple側の旧read-back（`automation/asc-results/hm2-release-readback.json`、2026-09-25実測）ではBuild 22 = `d97f10a1-dcce-40ed-be25-5e0a6563d7aa`、VALID、Version 1.0への紐付けが記録されている。**2026-11-12に更新した300問を含む新ビルドではないため、そのまま本審査用には使わない**。
- 旧Build 16も明確に失効。新ビルドの実際の対応iPhoneサイズ・実出題内容を実機で再照合する。
- 元の厳格リリースエクスポート`ios/health-manager-2/export-audit-data.cjs`は独立レビュー未承認時に停止する。監査スナップショット`export-canonical-snapshot.cjs`のPASSを公開承認へ読み替えない。
- 第4ラウンドの再生成バイト一致・18問90肢のAI内容判定PASSも、実名専門家承認とは別。公開BLOCKEDを維持する。

## 次の実施順
(1) シミュレーターCI結果の確認と必要なSwift/画面修正 → (2) 専門家・権利監査の承認証跡とClaude CSVの取込許可 → (3) 厳格エクスポータPASS → (4) 新署名ビルド・Apple read-back・実機/IAP試験 → (5) 実画面スクリーンショット・Privacy/年齢評価/審査メモの最終確認 → (6) **対象ビルドを固定したユーザー承認後のみ提出**。

**今回の申請実行数：0。ゲート解除数：0。**
