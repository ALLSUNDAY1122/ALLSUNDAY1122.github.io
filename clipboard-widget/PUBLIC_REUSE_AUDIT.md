# クリップボードWidget｜公開資産再利用監査

更新: 2026-08-26

## 方針
Phase 0 の実機Pasteboard技術ゲートは純度を維持するため、外部依存やApp Groupを追加しない。公開資産は、PASS-A後のMVPで必要になるInteractive Widget、App Group共有、Widget更新、データモデル構造の設計を短縮するために利用する。

## 採用可能｜MIT
### pawello2222/WidgetExamples
License: MIT. Copyright (c) 2020-Present Paweł Wiszenko.

確認した再利用対象:
- `Widgets/InteractiveWidget/InteractiveWidget+Intents.swift`
  - `AppIntent.perform()`で共有状態を書き換える構成
  - Intentへ対象Entityを渡してセルごとに独立操作する構成
- `Widgets/InteractiveWidget/InteractiveWidget+EntryView.swift`
  - `Button(intent:)`によるInteractive Widget操作
  - `.containerBackground(..., for: .widget)`
- `Widgets/AppGroupWidget/AppGroupWidget+Provider.swift`
  - App Groupの`UserDefaults`/共有ファイルからTimeline Entryを構成
  - 共有状態をWidget表示モデルへ変換する責務分離
- App/Widget双方のApp Group entitlement整合

本案件への適用:
- Large Widgetの各セルを個別`AppIntent`として扱う。
- MVPデータは`Snippet`と将来の`WidgetSet`を分離し、IntentにはSnippet IDを渡す構造にする。
- App Group共有ストアはApp/Widgetで同一契約にする。
- Widget側は編集責務を持たず、共有ストアを読みTimeline/Entryへ変換する。
- Widgetの状態更新は必要時にWidgetKitのreload経路を使う。

MITコードの実質的なコピー/改変を行う場合は、著作権表示とMIT許諾文を配布物のThird Party Noticesへ保持する。

## 参考のみ｜コードコピー禁止（ライセンス未確認または異なる技術スタック）
- `0Itsuki0/SwiftUIWidgetDemo`: Interactive Widget + App Group/UserDefaults構成の概念確認。ライセンスを確認できないためコードはコピーしない。
- `guilhermeyo/tsp` (Simple Phone): App編集画面とWidgetを別プロセスとして扱い、App GroupにJSONを置く製品構造を参考にする。ライセンス未確認のためコードコピーしない。
- `EvanBacon/expo-apple-targets`: Button/Toggle、App Group、Widget更新の実装上の注意点のみ参考。ネイティブSwiftプロジェクトへExpo依存は導入しない。
- `Maui.Apple.PlatformFeature.Samples`: App Group共有ファイル方式の注意点のみ参考。MAUI依存は導入しない。

## 不採用
- private APIを使用するWidget拡張。
- Clipboard監視/履歴収集ライブラリ。
- GPL等、現行配布方針と整合しない依存を無条件に組み込むこと。
- Phase 0のPasteboard成否を変える外部ライブラリ。

## 次の適用Gate
1. Phase 0実機でPASS-Aを確定。
2. App Group `group.jp.allsunday1122.clipboardwidget`を正式登録・両ターゲットへ付与。
3. MITパターンを基に、`Snippet` / `WidgetSet` / shared store / widget providerを本案件用に実装。
4. 日本語、改行、長文、URL、連続コピー、再起動後保持、App/Widget一致をテスト。
