# #15 理学療法士国家試験｜Native Audit Status

更新: 2026-08-12 JST

## 初回実装監査

- SwiftUI native shell: PASS（ホーム／模試／記録／設定）
- `WKWebView` / `UIWebView` / `WebKit`: 0件
- Golden Master v2.1署名要素: PASS（8問、分野導線、苦手、模試、進捗リング、5週間ヒートマップ）
- Bundle ID推測値: 0件。`$(RIGAKU_BUNDLE_ID)` 外部注入のみ
- 第60回: 厚労省公式PDFで午前100＋午後100＝200問を確認
- 第59回: 厚労省公式PDFで午前100＋午後100＝200問を確認
- 第58回: 厚労省公式PDFで午前100＋午後100＝200問を確認
- 3回分総枠: 600問
- 科目別600問分類: 未完了。推測配分を禁止し、`exam-config.json`確定ゲートとして保持

## 実行済み検査

ChatGPT実行環境で、GitHub反映ソースと同内容に対して以下を再実行。

```bash
python3 static_audit.py
swiftc -frontend -parse Sources/AppConfiguration.swift Sources/RigakuSprintApp.swift Sources/RootTabView.swift Tests/RigakuSprintConfigurationTests.swift
```

結果:

```text
STATIC AUDIT: PASS
Swift files: 3
WebView ban: PASS
Golden Master signature elements: PASS
Identifier non-guess policy: PASS
Official frame: R60/R59/R58 = 200 each, total 600: PASS
SWIFT PARSE: PASS
```

## XCTest

`RigakuSprintConfigurationTests.swift` を追加済み。

確認項目:
- Golden Master v2.1 の4／8／16問・標準8問
- 第60・59・58回が公式PDF確認済み200問×3＝600問であること
- 将来の未確認回を `officialQuestionCount=nil` で保持できるデータ型
- 第61回公式施行情報に対応した一般8科目・実地5科目

Xcode上でのXCTest実行は実Bundle IDを含むプロジェクト生成後に行う。

## 現在のビルドゲート

Xcode/iOS Simulatorの実ビルドは、正本Bundle IDが未確認であるため未実行。仮Bundle IDを作って通すことはしない。正本値確定後にXcodeGen→build→XCTest/UI Testを実行する。

## 次の品質ループ

1. 600問の科目分類監査
2. `exam-config.json`確定
3. 問題単位の権利フラグ／一次根拠付与
4. LearningSprintCoreの学習状態・中断再開・苦手・バックアップ接続
5. 問題生成・著作権・正答監査
6. Xcode build / XCTest / UI Test
