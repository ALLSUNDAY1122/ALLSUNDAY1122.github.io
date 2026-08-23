# 書籍スキャナー同等化｜4 Worker 完全委任Handoff

Effective: 2026-08-23 16:35 JST
Baseline integration: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`

全Worker共通：`WORKER_BOOTSTRAP.md v0.5` と `AUTONOMOUS_LANES.json` が最優先。HQの中間配車・merge・reviewを待たず、lane完了・self-review・final PRまで自律継続する。

## Worker 1
担当: `LANE-1-PRODUCT`
Branch: `scanner-parity/worker1-product-lane`

既に統合済みpipelineを実際のiPhoneアプリ体験へ完成させる。SwiftUI shell、入力、処理state/progress、cancel/resume、review入口adapter、BookPackage export/share、失敗復旧、Apple compile/product-flow testまで担当。AppShellはこのlaneへ正式委任済み。

完了までHQへ戻さない。最後に `LANE-1-FINAL.md` とintegration向けfinal PRを1本作成する。

## Worker 2
担当: `LANE-2-PRIVACY`
Branch: `scanner-parity/worker2-privacy-lane`

現在の `SCAN-011` を吸収する。既存 `task/SCAN-011/attempt-1` に未統合commitがあれば監査してlane branchへ取り込む。その後、Privacy static audit、network/external AI inventory、deny/allow regression、ログ/キャッシュ/一時ファイル、Privacy Manifest/Info.plist技術棚卸し、将来外部送信検知fixtureまで続行する。

完了までHQへ戻さない。最後に `LANE-2-FINAL.md` とintegration向けfinal PRを1本作成する。

## Worker 3
担当: `LANE-3-PACKAGE`
Branch: `scanner-parity/worker3-package-quality-lane`

現在の `SCAN-010` を吸収する。既存 `task/SCAN-010/attempt-1` に未統合commitがあれば監査してlane branchへ取り込む。その後、BookPackage integrity、searchable PDF text-layer、OCR品質、Markdown/TXT境界、manifest AI usability、破損/欠落/重複fail-close、Golden差し込み可能quality interfaceまで続行する。

完了までHQへ戻さない。最後に `LANE-3-FINAL.md` とintegration向けfinal PRを1本作成する。

## Worker 4
担当: `LANE-4-RECOVERY`
Branch: `scanner-parity/worker4-review-recovery-lane`

`SCAN-012` を吸収する。既存 `task/SCAN-012/attempt-1` が存在し未統合commitがあれば監査してlane branchへ取り込む。その後、ReviewQueue、修復/re-OCR/再撮影/保留/除外、stable-ID dedupe、checkpoint/resume、部分失敗recovery、200ページ級stress、AppShell用review/recovery adapterまで続行する。

完了までHQへ戻さない。最後に `LANE-4-FINAL.md` とintegration向けfinal PRを1本作成する。

## HQ
4本すべてのfinal PRが `LANE_READY_FOR_FINAL_INTEGRATION` になるまで原則standby。最後にcross-lane統合、Apple/E2E/Privacy/long-run regression、Golden Gate、実機/Release Gateをまとめて実施する。
