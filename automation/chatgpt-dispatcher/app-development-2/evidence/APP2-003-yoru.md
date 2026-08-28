# APP2-003｜夜の書架｜Guideline 4.3(a) 対応中

更新: 2026-08-29 07:12 JST
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去結果は開始点であり正本ではない。再開時は Notion / GitHub / App Store Connect / Codemagic をfresh readすること。

## 現在状態｜2026-08-29 07:12 JST

ユーザー提供のApp Store Connect画面で、Version 1.2.0が **Guideline 4.3(a) - Design - Spam** により却下されたことを確認。続けてASC API / Codemagic / GitHub / Notionをfresh readした。

ASC fresh read:
- Version `1.2.0`: `REJECTED`
- Version ID: `812cd84c-3efb-407b-a04c-f9fb1b5554e6`
- Review Submission ID: `be8d6f15-4ffe-409c-8078-3f3b331ba4bb`
- Review Submission state: `UNRESOLVED_ISSUES`
- Review item: `REJECTED`
- Selected Build: `b0fece05-6994-4602-afd5-17c3bdd69cee` = Build 7
- Build 7 processingState: `VALID`
- Build 7 buildAudienceType: `APP_STORE_ELIGIBLE`
- releaseType: `MANUAL`

Codemagic fresh read:
- Build ID: `6a910f0cfcbd73331ec99411`
- workflow: `yoru-ios-appstore`
- status: `finished`
- App Store Connect publishing: `finished`
- IPA: `App.ipa`, version `1.2.0`, build `7`, 12,809,827 bytes
- source commit: `0083095e354fb96a22afadba8a7f174bc5dc8220`

したがって今回の却下は署名・Build・upload・processingの失敗ではなく、App Reviewの4.3(a)ポリシー判定。

## Appleの指摘

Appleは、当該アプリが他の提出済みアプリとbinary / metadata / conceptのいずれかで類似し、差分が小さいと判断した。Appleメッセージは、同一source/assets、repackaged template、第三者template、複数アカウントにまたがる類似app等を4.3(a)要因として例示している。

Appleがどの既存appとのどの類似を検出したかは、現時点のメッセージでは特定されていない。

## 独自性の確認結果

現行repoのREADME / source treeを再監査:
- 端末内に148話を収録。
- `夜語り` 100話はrepoで「オリジナル怪談」と明記。
- `境界夜話` 48話は4シリーズ×12話。
- `public/stories.json` は約870KBのタイトル固有コンテンツ。
- 検索、怖さ・長さ・シリーズ絞り込み、お気に入り、読了記録、reader theme/brightness/font size/line spacing/font、共有、haptics、offline読書を実装。
- account / ads / analytics / IAPなし。
- product-specific UI/runtimeは `app/HorrorLibrary.tsx`、`ReaderRuntimeGuards`、専用CSSで構成。

一方、iOSのcontainerはCapacitor。binaryのframework部分が他のhybrid appと類似する可能性はあるため、Appleがbinary similarityを問題視した可能性は排除できない。ただし、現時点でAppleが比較対象appや類似箇所を明示していないため、原因を断定しない。

開発者保有repoも一部横断確認。`nomikai-arcade-ios` はSwiftUI/native構造で夜の書架とは別構造。`kyokai-yawa` は関連コンテンツを持つWeb/static repoだが、これだけでApp Store上の4.3(a)比較対象だったとは判定しない。

## 採用方針

**見た目・説明文だけ変更して即再提出しない。**

第一選択は、製品固有性を事実ベースで説明し、Appleにbinary / metadata / asset / conceptのどの類似が問題か追加情報を求めつつ、4.3(a)の再考を求めること。

Appleの案内上、App Review Boardへのappealは一回の却下につき一回として扱うため、文面は準備するがユーザー承認なしに送らない。

appeal packetはapp repoへ保存済み:
- `docs/APP2-003_GUIDELINE_4_3A_APPEAL.md`
- commit `00bab5bd6b827c5f69359ffd7d84089fcc495620`

appealが不成立、またはAppleが実質的な類似を具体的に指摘した場合のみ、第二段階として物語固有の大きな機能差分（例: 作品横断の人物・場所・反復モチーフ・伏線・時系列探索）を実装する。source変更後は旧実機PASSを失効させ、新Internal TestFlightで再受入してから再申請する。

## 既往Build

- Build 4: 実機UX不具合でFAIL
- Build 5: native entrypoint未接続でFAIL
- Build 6: Internal TestFlightでユーザー実機PASS
- Build 7: 同一sourceのApp Store候補。Build/ASC processingはPASSしたがApp Review 4.3(a)でREJECTED

## 現在の人間Gate

**4.3(a) appeal / reconsideration文面をAppleへ送ることへのユーザー承認。**

承認前に新Build作成・cosmetic再提出・appeal送信は行わない。

## 禁止事項

- Codexは使わない。
- secret/token/.p8/private keyをGitHub/Notion/evidence/logへ保存しない。
- 4.3(a)をBuild失敗と誤認しない。
- Appleが比較対象を明示していない段階で原因appを断定しない。
- superficial changeだけで再提出しない。
- 一回限りのappealをユーザー承認なしに消費しない。
