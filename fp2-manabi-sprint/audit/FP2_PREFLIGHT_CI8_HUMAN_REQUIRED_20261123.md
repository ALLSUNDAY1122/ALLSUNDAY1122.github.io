# FP2｜5a72059f CI証拠とpreflight分類・2026-11-23 20:44 JST

## 対象を固定した証拠
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Release branch: `feature/fp2-release-scope-20261123`
- Verified commit: `5a72059f69e77375dbfa6568f613362a2712cc75`
- GitHub REST `commits/{sha}/check-runs` の読戻し: **check-runs 8件中success 8件、queued 0件、failure 0件**。
- 同コミットのActions workflowsにはFP2とは無関係な他アプリのfailed runsも存在。FP2 8ジョブと混同しない。
- 記録更新後の新しいコミットのCIも自動でPASSしたとはみなさない。

| FP2チェックジョブ | 状態 | GitHub Actions |
|---|---|---|
| chromium-e2e | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158866148 |
| static-and-native-simulator | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158866204 |
| static-content-and-web-shell | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158862331 |
| static-content-and-web-shell | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158861394 |
| audit | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158861290 |
| migration-gate | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158860974 |
| chromium-e2e | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158860711 |
| static-and-native-simulator | SUCCESS | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45158860920 |

## preflight区分（5a72059fの実証範囲）
| 項目 | 区分 | 留保 |
|---|---|---|
| 静的問題バンク・Webソース | CI_PASS_VERIFIED_AT_5a72059f | 内容監査と公開権利許諾は別 |
| Chromium学習・オフライン | CI_PASS_VERIFIED_AT_5a72059f | 物理iPhone/iPadのユーザー受入ではない |
| UI Master v2.1移行 | CI_PASS_VERIFIED_AT_5a72059f | Golden Master全実機状態受入とは別 |
| iOS Simulatorビルド | CI_PASS_UNSIGNED_SIMULATOR_AT_5a72059f | 署名済みIPA/ASC/TestFlightではない |
| Release Registry監査 | CI_PASS_VERIFIED_AT_5a72059f | Apple App Store Connectのライブreadbackではない |
| アイコン内部一致 | PASS_SAME_GIT_BLOB_SHA | 現行iOSと旧`fp2-kakomon-coach`のBlob `ce0cb5bc61296d7ca2ebde213c729ae5d1e4ab9d`、SHA-256 `d456178b2a7b04f180e39b3ad62f5c194832e85aa15102bf6452751551db8033` |
| ASCに登録済みのアイコン一致 | HUMAN_REQUIRED | Apple側現物のreadbackなし |
| 発行可能な教材 | BLOCKED_Q0_PUBLICATION | canonical195、release120、reserve75、publishable0。CI PASSは権利利用許諾ではない |

## HUMAN-REQUIRED（本件での更新）
1. **ASC側のアイコン一致**：App ID `6797228406` の登録済み画像とリポジトリ内FP2画像の同一性をApple側現物・管理者証跡で確認。内部GitHubバイト一致の再照合は不要。
2. **ASC登録情報・App Privacy・ストア表示の最終確認**：Bundle ID `com.allsunday1122.fp2manabisprint`、Version `1.0.0`、Build `1`、初回IAPなし、プライバシー回答、サポート・プライバシー公開URLと説明・スクリーンショット。Apple側に実際に登録されたことは未確認。
3. **実機受入**：署名ビルドとTestFlightが準備された後、iPhone/iPadで出題、正誤、学習復帰、Safe Area、オフライン、JSONバックアップ、アクセシビリティ、画面記録を検証・承認する。
4. **事業者/権利/出典/改変表示**：日本FP協会・きんざいの利用条件、利用主体と第三者著作物非混入、問い合わせ・運営主体、2026-04-01法令基準の表示について責任者の最終承認。
5. **最終公開許可**：Q0〜Q5とASC/実機の最終ゲートをすべて通した後、App Reviewへの提出についてユーザーの明示的な最終許可を得る。

## HUMAN-REQUIREDではない未完の技術作業
- 署名済みIPAと実配布バンドルのSHA一致、App Store Connect/TestFlightへの配布経路構築・証拠保存。
- GitHub Pages上のサポート/プライバシーURLの実際のHTTP到達確認と未完事項の修正。
- 新規2024-09/2024-05学科120問の別ブランチ制作・独立監査・統合。これは将来300問スコープであり、初回120問のリリース固定を変更しない。

**結論：FP2 8/8 CI_SUCCESS_ON_5a72059f / HUMAN_REQUIRED_REMAIN / Q0–Q5 NOT_CLEARED / NOT_SUBMISSION_READY / NOT_SUBMITTED。**
