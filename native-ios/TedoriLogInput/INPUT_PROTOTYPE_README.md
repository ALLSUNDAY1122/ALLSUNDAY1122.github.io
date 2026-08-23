# INPUT_PROTOTYPE_README｜手取りログ iPhone入力試作

製品チェック1に出すための**入力体験の試作**。PoC（`tedorilog-poc/`）を本番候補の形へ昇格させたもので、
Apple Vision（端末内OCR）とPDFKitを使う。

判定と数値は [VISION_EVAL_RESULTS.md](./VISION_EVAL_RESULTS.md)、
失敗の分類は [VISION_FAILURES.md](./VISION_FAILURES.md)、
製品チェック1への引き渡しは [PRODUCT_CHECK1_HANDOFF.md](./PRODUCT_CHECK1_HANDOFF.md)。

## 守っている制約

- 明細の画像・PDF・読み取り結果を**外部へ送信しない**。OCRは端末内のVisionのみ。
- 実在の給与明細・個人情報は扱わない。評価コーパスは全て合成データ。
- **ユーザー確認なしに保存できない**（`SaveGuard` がコードとして保証）。
- 確信が持てない値は必ず「要確認」に倒す。精度より安全性を優先する。

## 構成

```
Sources/
  TedoriLogCore/      解析エンジン（Apple製フレームワークに依存しない）
    Normalize.swift     文字・金額の正規化（全角/¥/△/括弧/OCRのゆれ）
    Lexicon.swift       9項目の判定。語の列挙ではなく「語の作られ方」で判定する
    Layout.swift        行・列の再構成（トークン連結・傾き推定・順序保存マッチング）
    Extract.swift       候補生成・割当・整合検算・状態判定
    DigitRepair.swift   合計整合による桁誤り補正（曖昧なら補正しない）
    SaveGuard.swift     ユーザー確認なしの保存を禁止する層
  TedoriLogVision/    入力経路（Apple製フレームワーク）
    PDFTextExtractor.swift   PDFKitで埋め込みテキストを取り出す（第一経路）
    VisionTextRecognizer.swift  VNRecognizeTextRequest（日本語, .accurate）
    ImagePreprocessor.swift     再OCR用の画像補正（照明ムラ・コントラスト・拡大）
    CaptureQuality.swift        撮影品質の判定と撮り直し誘導
    PayslipImporter.swift       経路選択と条件付き再OCR
App/                  iPhone試作アプリ（SwiftUI）
Fixtures/holdout/     未知形式コーパス30形式（評価20 / 最終確認10）
tools/                コーパス生成・トークン化スクリプト
Tests/                単体テスト、JS版との一致確認、実Visionでの評価
```

## 入力経路

```
PDF ──→ PDFKitで埋め込みテキスト ──(8トークン以上)──→ そのまま解析
          └─(テキスト無し=スキャンPDF)─→ ページを画像化 ─┐
写真・スクリーンショット ───────────────────────────────┤
                                                        ↓
                                            Apple Vision 日本語OCR
                                                        ↓
                                   自己評価が低い or 平均信頼度が低い場合だけ
                                   画像補正して**2回目のOCR**（常時2回は走らせない）
                                                        ↓
                                     2つの読み取りで値が食い違う項目は「要確認」へ
```

`PayslipImporter.reOcrThreshold` / `reOcrConfidence` が再OCRの判断基準。
読みやすい入力では1回で終わるため、実機の処理時間と電力への影響を抑えられる。

## 判定の状態

| 状態 | 意味 | 保存 |
| --- | --- | --- |
| 確定候補 | 合計との検算が合い、読み取り信頼度も高い | ユーザー確認後のみ |
| 要確認 | 値はあるが裏付けが不十分、または読み取り条件で値が割れた | ユーザー確認後のみ |
| 未検出 | 候補を作れなかった | 空欄のまま保存可 |

**どの状態でも、確認しない限り保存されない。** これは `SaveGuard.buildDraft` が構造的に保証しており、
テスト（`testSaveGuardBlocksUnconfirmed`）で守っている。

## 実行方法

```bash
cd native-ios/TedoriLogInput

# 解析ロジックの単体テストとJS版との一致確認（Mac/Linuxどちらでも動く部分）
swift test --filter TedoriLogCoreTests

# 実Apple Visionでの未知形式評価（macOSが必要。CIはこれを毎回流している）
swift test --filter TedoriLogVisionTests

# iPhone試作アプリ
brew install xcodegen && xcodegen generate && open TedoriLogInput.xcodeproj
```

コーパスを作り直す場合（通常は不要。生成物はコミット済み）:

```bash
python3 tools/generate_holdout.py      # 合成明細30形式を生成
python3 tools/build_holdout_tokens.py  # PDF抽出とローカルOCRでトークン化
```

## 評価コーパスについて

`Fixtures/holdout` はPoCのfixtureとは**別の生成規則**で作った未知形式。

- レイアウト原型7種（縦1列・2段組・勤怠ブロック付き・列ヘッダ・罫線なし等幅・合計行なし・複数ページ）
- 語彙プールから項目名を毎回選び直す（PoC辞書に無い言い回しを含む）
- 媒体4種（テキストPDF・スクリーンショット・写真・スキャンPDF）
- 写真は透視ゆがみ・手ブレ・低照度・ビネット・JPEG圧縮を加える
- `split=eval` の20形式で調整し、`split=final` の10形式は最後に1回だけ使う

実データではないため、これで良い数値が出ても実データの保証にはならない。
実データでの再測定は製品チェック1と並行して必要。
