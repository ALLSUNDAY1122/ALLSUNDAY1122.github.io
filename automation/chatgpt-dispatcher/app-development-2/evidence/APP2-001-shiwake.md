# APP2-001｜仕訳スワイプ｜公開済み状態から再開

確認時刻: 2026-08-19 12:20 JST
担当: SHIWAKE / セッション「仕訳スワイプ②」

## 判定

DONE。新Buildは起動しない。

## 再取得した正本・実状態

- Worker契約: `automation/chatgpt-dispatcher/app-development-2/WORKER_BOOTSTRAP.md`。完了済み作業を再実行せず、ASC/Codemagic/GitHubはread→canonical比較を優先する契約を確認。
- Queue: APP2-001はREADY、人間Gateなし、目的は公開版1.0 Build 4とTestFlight 1.0.1 Build 5の再確認、および更新版を進める根拠の有無判定。
- Notion台帳: 「仕訳スワイプ」は状態「公開済み」。次の作業は「現行App Store公開1.0 / Build 4は不足なし。TestFlight 1.0.1 / Build 5はBeta Review APPROVED。更新版を公開する場合のみ、変更差分の実機回帰→Submission audit→最終承認後にリリースする。」
- Notion横断同期 2026-08-19: GitHub実状態・直近実機結果・App Store Connect横断監査・各アプリ正本を基に同期し、仕訳スワイプを「現行1.0 / Build 4公開済み、TestFlight 1.0.1 / Build 5はBeta Review APPROVED」と記録。
- App Store Connect read-only Gateway: 2026-08-19 12:18 JSTに`/v1/apps?limit=200`を実行し、App ID `6794796078`、Bundle ID `jp.allsunday1122.shiwakeswipe`、SKU `jp.allsunday1122.shiwakeswipe`、primaryLocale `ja` をApple APIからread-backした。Buildや提出は起動していない。
- GitHub main: 現行製品ディレクトリは`shiwake-swipe/`。仕訳スワイプに一致する直近コミットは2026-07-24のUI更新系列で、それ以降に仕訳スワイプ本体の新規変更を示すコミット/PRは確認できなかった。
- Codemagic: リポジトリの安全なBuild Gatewayは`inspect`/`inspect_build`/`build`を分離し、`build`のみがビルド起動を行う。今回は製品差分がないため、Build actionは実行していない。ルート`codemagic.yaml`にはApp Store Connect integration `Codemagic Shiwake Swipe`が現存する。

## 差分・不具合・申請残件の判定

- 公開版に対する新規ユーザー実機不具合: 今回の正本/Queue/直近同期には未解決報告なし。
- mainに未反映の仕訳スワイプ製品変更: 確認できず。
- 公開版1.0 Build 4を失効させるUI/教材/Privacy/課金変更: 確認できず。
- 1.0.1 Build 5: 最新横断監査でBeta Review APPROVED。公開を進める新しい要件・修正根拠は確認できず。
- `shiwake-swipe/docs/app-store-release-checklist.md`には初期MVP時代の未完了チェックが大量に残るが、公開済み/ASC実状態と矛盾するため現行リリース状態の正本とは扱わない。文書更新が必要なら別タスク化する。

## 結論

現時点では「差分→実機回帰→Submission audit」を再開する条件を満たさない。不要な再Buildは行わず、現行公開版を維持する。次回は新しい不具合報告、製品コード/UI/教材/Privacy/課金変更、または1.0.1公開を進める明示的判断が発生した場合のみ、旧PASSを失効させて更新フローへ入る。

## 付帯変更

ASC read-only Gatewayのsanitized summaryで今後release stateを保存できるよう、`versionString` / `appStoreState` / `betaReviewState`を非秘密属性の許可リストへ追加した。これはBuild/提出を起動しない観測機能の改善。
