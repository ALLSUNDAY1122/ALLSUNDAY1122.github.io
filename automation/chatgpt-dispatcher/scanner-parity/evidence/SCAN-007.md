# SCAN-007 Evidence｜Apple SDK Adapter統合Compile Harness

- worker: `worker1`
- claim_token: `fadae271-9098-478a-bff6-489d1e1ba621`
- claim_epoch: `1`
- attempt_branch: `task/SCAN-007/attempt-1`
- baseline_sha: `1bb35c1070477fdc34d0082291e64e48a84abf91`
- integration_epoch: `2`
- golden_status: `PENDING_HQ_GOLDEN`
- task_status_at_evidence: `BLOCKED_DEPENDENCY`

## 実装

`scanner-parity/AppleValidation/` にApple SDK専用compile harnessを実装した。

- `run-apple-sdk-compile.sh`
  - macOS/Darwin + `xcrun` + iPhoneOS SDKを必須化。
  - `FrameExtraction`、`ImageCorrection`、`PageAudit`を同一 `arm64-apple-ios17.0` target（環境変数で変更可）へ個別module compile。
  - Linuxで `canImport` により除外される `AVFoundationStableFrameExtractor.swift` / `ApplePageCorrectionEngine.swift` / `VisionPageAuditRecognizer.swift` / `PagePerceptualHasher.swift` をApple SDKで直接検査する。
  - 3 module compile後に `AppleAdapterContractProbe.swift` を同一targetからtypecheckする。
  - Xcode / Swift / iPhoneOS SDK version / target / status / failure detailを `report.json`、compiler outputを `compile.log` に保存する。
  - Apple SDKが存在しない環境では非0終了し、擬似PASSしない。
- `AppleAdapterContractProbe.swift`
  - `FrameExtraction` / `ImageCorrection` / `PageAudit` を同時import。
  - `AVFoundationStableFrameExtractor`、`PageCorrectionEngine`、`VisionPageAuditRecognizer`のpublic surfaceを参照。
  - AVFoundation / CoreGraphics / CoreImage / Visionの代表型も同一targetで参照する。
- `scanner-parity/Tests/AppleValidation/harness_contract_test.py`
  - shell syntax、Apple source coverage、iPhoneOS target、3-module probe、Golden判定非所有を検証。
- `README.md`
  - macOS実行手順、出力、fail-fast、Golden Gateとの責任分離を記録。

## Fixture / Harness Test

Apple SDK不要の退行テストをLinux環境で実施。

- `python3 scanner-parity/Tests/AppleValidation/harness_contract_test.py`
- 結果: **5 tests / 0 failures**

検証内容:

1. `bash -n` によるHarness shell syntax PASS。
2. FrameExtraction / ImageCorrection / PageAuditのApple adapter sourceがcompile対象に含まれる。
3. iPhoneOS SDK指定と3 module + cross-module typecheckが存在する。
4. probeが3 moduleおよびAVFoundation/Vision等のApple型を参照する。
5. reportが正式Golden判定を持たず `GOLDEN_PASS` を生成しない。

HarnessをLinux上で直接実行するfail-fast testも実施。

- exit code: `20`
- report status: `FAIL`
- failure_detail: `Apple SDK validation requires macOS/Darwin.`
- Xcode / SDK: `unavailable`

Apple SDKのない環境で成功扱いにならないことを確認した。

## Apple SDK実測依存

このWorker実行面にはmacOS/Xcode/iPhoneOS SDKがなく、接続済みGitHub toolにもworkflow dispatch機能がない。repository内の既存macOS workflowもscanner-parity pathを対象にしていない。

Workerのwrite scopeは `scanner-parity/AppleValidation/**` と `scanner-parity/Tests/AppleValidation/**` であり、HQ所有領域の `.github/workflows/**` を新規変更してCIを起動することは契約違反になるため行っていない。

したがって以下のAcceptanceは未実測:

- iPhoneOS SDKによる3 module実compile成功/失敗。
- Xcode / Swift / iPhoneOS SDKの実version付き成功・失敗ログ。
- Apple SDK上でのみ顕在化する型/API不整合の有無。

これはGolden Dataset未取得やSHA mismatchによる停止ではなく、**Apple SDK runnerが現在のWorker実行面に存在しない技術依存**である。よって `BLOCKED_HUMAN` にはせず `BLOCKED_DEPENDENCY` とする。

macOS runnerが利用可能になれば、次の1コマンドで再開できる。

```bash
bash scanner-parity/AppleValidation/run-apple-sdk-compile.sh /tmp/scanner-parity-apple-validation
```

## Golden責任分離

- Golden Dataset原本は使用していない。
- canonical SHA採否は行っていない。
- 正式Golden PASS/FAILは行っていない。
- Golden部分は `PENDING_HQ_GOLDEN` のままHQ `HQ_GOLDEN_GATE` 所有。

## Remote commits

- `0a663727dd7cb941283b13c117ea22ab397b51e0` Apple SDK compile harness
- `1b098fc5aa18480ac4caf647fb2cbe181812932a` cross-module contract probe
- `ba85331e5fa9020a08c28b0c53080bdeedbc6418` harness contract tests
- `6f9493189e450d1d7d84c0fceab60814d46ce625` README / execution contract
