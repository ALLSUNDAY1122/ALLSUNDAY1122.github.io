# SCAN-007 Apple SDK Adapter Compile Harness

目的は、Linux fixtureでは `canImport` により除外されるApple Framework実装を、同一iPhoneOS SDK targetで実コンパイルして型/API不整合を検出することです。Golden Datasetの内容・SHAの採否・正式PASS/FAILは扱いません。

## 対象

- `FrameExtraction`：AVFoundation / CoreMedia / CoreVideo / ImageIO
- `ImageCorrection`：CoreGraphics / CoreImage / Vision
- `PageAudit`：Vision / ImageIO / CoreGraphics
- `AppleAdapterContractProbe.swift`：上記3 moduleを同じiPhoneOS targetからimportし、代表的public surfaceとApple SDK型を横断typecheck

## 実行

macOS + Xcode Command Line Tools環境でrepository rootから実行します。

```bash
bash scanner-parity/AppleValidation/run-apple-sdk-compile.sh /tmp/scanner-parity-apple-validation
```

既定targetは `arm64-apple-ios17.0` です。必要なdeployment targetが確定している場合は次のように上書きできます。

```bash
APPLE_VALIDATION_TARGET=arm64-apple-ios16.0 \
  bash scanner-parity/AppleValidation/run-apple-sdk-compile.sh /tmp/scanner-parity-apple-validation
```

## 出力

- `compile.log`：Xcode/Swift/SDK情報と各module/probeのcompiler output
- `report.json`：status、exit code、Xcode/Swift/iPhoneOS SDK/target、対象module、失敗理由
- `build/*.swiftmodule`：compile時の一時成果物

`report.json.formal_golden_decision` は常に `null` です。このHarnessのPASSはApple SDK compile整合だけを意味し、`HQ_GOLDEN_GATE` の正式Golden判定を代替しません。

## Fail-fast

Darwin以外、`xcrun`/`xcodebuild`/`python3`不足、iPhoneOS SDK不足、対象source欠落、module compile失敗、横断contract probe失敗は非0終了します。Apple SDKが存在しない環境で擬似PASSしません。

## Fixture contract test

Apple SDKを持たないLinuxでもHarness自体の退行を検出できます。

```bash
python3 scanner-parity/Tests/AppleValidation/harness_contract_test.py
```

このテストはshell syntax、Apple source coverage、iPhoneOS target指定、3 module横断probe、Golden判定非所有を確認します。
