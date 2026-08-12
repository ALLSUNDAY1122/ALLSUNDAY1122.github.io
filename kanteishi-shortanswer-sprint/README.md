# 不動産鑑定士試験・短答式｜学びスプリント（開発連番#12）

SwiftUIネイティブiOSアプリとして開発する。WebViewだけの実装は禁止。

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d813f8d55fa0735c1e502
- 資格正本: https://app.notion.com/p/3b509c10697d8179927af2d9b99a3d7a
- 共通UI正本: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- UIは現行最上位 v2.1 Golden Masterを適用。v1.0の学習目的・主要機能は互換維持するが、UI競合時はv2.1を優先する。

## 現在の実装

- `core/`: Swift Package。資格モデル、8問スプリント、年度/科目フィルタ、苦手3連続正解解除、わからない履歴、中断状態、JSONバックアップ、問題品質監査、未確定StoreKit IDガード。
- `ios/KanteishiShortAnswer/NativePrototype.swift`: v2.1の主要デザイントークン、28px方眼、最大幅520、18px外周、82px進捗リング、4タブを用いたSwiftUI初期画面。
- `docs/RESEARCH_AND_RIGHTS.md`: 市場・競合・公式問題枠・利用条件・独自問題化方針。
- `docs/ACCEPTANCE.md`: フェーズ、受入条件、ブロッカー。
- `AUDIT-2026-08-12.md`: 初期監査結果。

## 公式問題枠

対象は令和8・7・6年。各年度は行政法規40問＋鑑定理論40問の80問、合計240問。240スロットを固定し、水増し禁止。

## 未確定のためコードへ入れない値

- App Store Connect App ID
- Bundle ID
- StoreKit 2 Product ID / 商品構成 / 価格
- #12固有Apple署名・プロビジョニング

## 開発ルール

変更 → 対応する品質ループ → 静的監査 → 単体/UIテスト → FAIL修正 → 再テスト → Notion/GitHub正本更新、を小さく反復する。

外部TestFlightベータ審査およびApp Store本審査はユーザー承認まで実行しない。
