# #15 理学療法士国家試験｜Native Audit Status

更新: 2026-08-12 JST

## 初回実装監査

- SwiftUI native shell: PASS（ホーム／模試／記録／設定）
- `WKWebView` / `UIWebView` / `WebKit`: 0件
- Golden Master v2.1署名要素: PASS（8問、分野導線、苦手、模試、進捗リング、5週間ヒートマップ）
- Bundle ID推測値: 0件。`$(RIGAKU_BUNDLE_ID)` 外部注入のみ
- 第59・58回問題数: 未確認のため `nil` を維持
- 第60回問題数: 厚労省公式PDFで午前100＋午後100を確認したため200のみ固定

## 実行済み検査

ChatGPT実行環境で、GitHub反映前の同一ソースに対して以下を実行。

```bash
python3 static_audit.py
swiftc -frontend -parse Sources/AppConfiguration.swift Sources/RigakuSprintApp.swift Sources/RootTabView.swift
```

結果:

```text
STATIC AUDIT: PASS
Swift files: 3
WebView ban: PASS
Golden Master signature elements: PASS
Identifier non-guess policy: PASS
Unverified exam counts remain unset: PASS
SWIFT PARSE: PASS
```

## XCTest

`RigakuSprintConfigurationTests.swift` を追加済み。

確認項目:
- Golden Master v2.1 の4／8／16問・標準8問
- 第59・58回問題数を未確認のまま固定しない
- 第61回公式施行情報に対応した一般8科目・実地5科目

## 現在のビルドゲート

Xcode/iOS Simulatorの実ビルドは、正本Bundle IDが未確認であるため未実行。仮Bundle IDを作って通すことはしない。正本値確定後にXcodeGen→build→XCTest/UI Testを実行する。

## 次の品質ループ

1. 第59・58回PDFの構成・問題数監査
2. `exam-config.json`確定
3. LearningSprintCoreの学習状態・中断再開・苦手・バックアップ接続
4. 問題生成・著作権監査
5. Xcode build / XCTest / UI Test
