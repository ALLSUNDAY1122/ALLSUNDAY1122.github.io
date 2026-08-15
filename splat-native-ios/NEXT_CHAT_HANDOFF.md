# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-15 12:41 JST

## 最重要
次チャットでは**まだA〜Dへ分割しない**。

このチャットの後継として、統合本部 `feature/splat-native-ios-poc` をそのまま引き継ぎ、単一チャットで開発・統合・辛口レビュー改善を継続する。

A〜Dの4開発班構成は将来の分割先として設計済みだが、ユーザーが明示的に分割開始を指示するまで新規A/B/C/Dチャットを要求・開始しない。

## 現在の正本
- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- Integration branch: `feature/splat-native-ios-poc`
- Integration PR: #4145 `Scan Lab｜Scaniverse同等化 統合本部（4開発班）`
- Working root: `splat-native-ios/`
- Parity plan: `SCANIVERSE_PARITY_PLAN.md`
- Lane definitions: `SESSION_PROMPTS.md`

## 旧S構成
旧S0〜S8方式は廃止済み。旧S1〜S8 PRはSOURCE/SUPERSEDEDとしてclosedし、移植元・証拠としてのみ保持する。新規開発はしない。

## 将来の分割設計（今は起動しない）
- A: 撮影 → Gaussian Splat生成
- B: Splat閲覧/編集/計測 + Mesh
- C: 保存/再開/再処理 + Export/Video
- D: Account/Publish/Browser/Map/Discover

## 次チャットで最初にやること
1. Notion v2.0、本ファイル、`SCANIVERSE_PARITY_PLAN.md`、PR #4145、integration branchの最新HEAD/CIを取得する。
2. 過去チャットの進捗数字ではなくGitHub実状態を正とする。
3. A〜Dへ分割せず、現在散在している旧S成果と新lane資産を統合本部へ意味的に回収する優先順位を決める。
4. `実状態確認 → 最大差分の実装/統合 → test/build/runtime → 辛口レビュー → 改善 → 回帰gate` を、人間判断が必要になるまで継続する。
5. branchにcommitがあるだけでは進捗とみなさない。統合アプリのユーザーフローとして動いて初めて進捗。

## 禁止
- 「A〜Dを作ってください」とユーザーへ要求すること
- 管理・差分表作成だけで作業を止めること
- compile PASSをScaniverse同等化完了と扱うこと
- fake 3D / fake export / fake progress / hardcoded Mapを合格扱いすること
