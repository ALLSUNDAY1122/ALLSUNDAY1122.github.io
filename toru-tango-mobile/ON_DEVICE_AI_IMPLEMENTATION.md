# 端末内AI作問 実装記録

更新日: 2026-07-31

## 目的

Apple Foundation Modelsを使い、Apple Vision OCRの編集済み文字列から「問題・答え・解説・根拠・確信度・タグ」を端末内で生成する。Foundation Modelsを使えない場合も、既存機能を止めずに決定的なルールベース作問へ切り替える。

## 構成

- `modules/toru-tango-ondevice-ai`: Swift実装とExpo Modules APIブリッジ
- `app/(tabs)/create.tsx`: OCR編集、生成、候補編集・選択、保存UI
- 既存の`Card`、AsyncStorageキー、履歴、JSONバックアップ形式は変更しない
- 保存時に端末内AIの候補を既存の`QuestionCandidate`（問題・答え）へ変換する

## Foundation Models利用条件

すべてを満たす場合だけ端末内モデルを使う。

1. ビルドSDKに`FoundationModels`が存在する
2. iOS 26.0以降
3. `SystemLanguageModel.default.isAvailable`が真

`@Generable`と`@Guide`による構造化出力を使い、最大20枚、原文最大12,000文字、確信度0.65以上、根拠と原文の主要語一致、重複問題・答えの除外を適用する。

## フォールバック条件

- iOS 26未満
- Apple Intelligence非対応端末
- Apple Intelligence無効
- モデル準備中またはその他の利用不可状態
- モデル呼び出し失敗
- 生成結果が品質フィルターを全件不通過

ルールベースでもカードを抽出できない場合だけ、編集済みOCR文字列を確認するエラーを表示する。

## UIとデータ

- OCR結果は生成前に編集、消去、撮り直しが可能
- 生成中は二重実行を防止し「iPhone内で作問しています…」を表示
- 各候補の問題・答え・解説を編集可能
- 根拠・確信度・タグ・使用エンジンを表示
- 候補ごとの保存対象切替、削除、再生成、OCR結果へ戻る操作を提供
- 解説・根拠・確信度・タグは保存前確認用で、既存v1データ形式には書き込まない

## 検証方法

- Windows: TypeScript、ESLint、Expo config、Expo Modules autolinking
- macOS/Xcode 26: `swift test --package-path modules/toru-tango-ondevice-ai`
- EAS: iOS development/production buildでSwiftコンパイル
- 実機: 対応端末と非対応条件の両方で生成、編集、選択保存、既存カード学習、バックアップ復元を確認

## 2026-07-31 検証結果

- TypeScript `tsc --noEmit`: 成功
- ESLint `app src modules`: 成功
- 既存OCR簡易作問回帰テスト: 3件成功
- iOS向けMetro export: 成功（1,586 modules）
- Expo Modules autolinking: `toru-tango-ondevice-ai`を検出
- EAS iOS production build: 成功
  - Build ID: `0f05bb63-79c6-4160-8cfb-99d4bdcce31a`
  - App version/build: `1.0.0 (1)`
  - Distribution: App Store
- Expo Doctor: 初回15/20。CIでもExpo SDK 57のパッチバージョン差分により失敗したため、推奨パッチ版10件へ限定更新し、最終20/20成功
- `npm ci --ignore-scripts`: 成功（package-lock整合性確認）
- Swift Package単体テスト: WindowsではSwift/Xcodeを実行できないため未実行。テストコードを同梱し、EAS buildでSwift本体のコンパイルを確認
- 実機でのApple Intelligence作問: 未確認。対応iPhone、iOS 26、Apple Intelligence有効状態で確認が必要
