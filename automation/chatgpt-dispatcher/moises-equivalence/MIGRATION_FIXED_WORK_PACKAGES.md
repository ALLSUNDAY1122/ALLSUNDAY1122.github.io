# 2026-08-22｜Fixed Work Package方式への移行

## 移行理由
旧方式はWorker 1〜4とHQが同一 `queue.json` をCAS更新し、READY Taskを動的claimしていた。実際の運用でHQ finalizationとWorker heartbeat/completion更新が同時発生し、409競合が確認された。

コードのwrite scopeが別でも、進捗管理ファイルが共有writerである限り競合点が残るため、運用を変更する。

## 新方式
- Global Queue: HQ-only writer。
- Work Package: Phase開始前に `工数 × 依存関係 × logical resource` で固定割当。
- Worker: 他packageをclaimしない。
- Branch: packageごとのlong-lived branch。
- Progress: Workerごとの専用status file。
- Shared / App / PARITY / Resource ownership: HQ-only。
- Rebalance: Phase境界またはHQの明示的blocker reviewのみ。

## Assignment epoch 1
- Worker 1 / WP1: Separation + Processing — 11pt
- Worker 2 / WP2: IO + Library — 10pt
- Worker 3 / WP3: Playback + DSP — 10pt
- Worker 4 / WP4: Analysis + Build/iOS Platform — 10pt

## 競合防止効果
1. Worker/HQのQueue CAS競合を除去。
2. Worker間のlogical resource競合をowner固定で除去。
3. Package.swift / Tests / iOS targetをWorker 4専有にしてbuild integration競合を除去。
4. Worker statusを4ファイルへ分割し、進捗報告の同一ファイル更新を除去。
5. 空きWorkerのopportunistic claimを禁止し、途中の担当変更によるsemantic collisionを除去。

## Trade-off
Workerが早く終わっても他packageを勝手に手伝わないため、短期の計算資源利用率は下がる場合がある。ただしPhase境界でHQが残工数とcritical pathを見て再配分する。安定性と再現性を優先する。

## Migration safety
移行時点では次Wave Taskにactive claimは存在しなかったため、進行中attemptを切断せず移行できた。旧Queueの詳細履歴はGit historyと既存PR/attempt branchに保持する。
