# Moises同等化｜Lane 1 Separation / Processing 完成ロードマップ

Captured: 2026-08-23 JST
Owner: `Moises-Worker-1`
Lane: `LANE-1-SEPARATION-PROCESSING`
Branch: `moises/wp1-separation-processing`
Owned scope: `Separation/**`, `Processing/**`

## 0. このロードマップの目的

Lane 1の役割は、合法かつ商用品質で使える source separation と processing lifecycle を完成させること。

「コードがある」「テストが通る」「評価ハーネスがある」だけでは完成としない。最終的には、現行iPhone版Moisesのin-scope separation / processing体験について、実音源・実provider・実失敗条件・差分A/Bの証拠まで揃え、HQがPARITY判定できる状態へ持ち込む。

対象する主PARITY行:
- `MOI-P003` vocals / drums / bass separation
- `MOI-P004` other / instrument separation
- `MOI-P005` advanced instrument separation / Hi-Fi / Pro stem modules
- `MOI-P020` progress / cancel / retry / resume

Lane 1が強く寄与するQUALITY行:
- `MOI-P021` long audio / memory / thermal / battery stability
- `MOI-P024` user content privacy / deletion behavior

## 1. 現在地

Epoch-2 bootstrapの `L1-M01`〜`L1-M04` は完了済み。

既存成果:
- rights-aware G1/G2 evaluation package
- objective SI-SDR / reconstruction evaluation
- blind listening schema
- provider capability / stable idempotency seam
- ambiguity / cancel / reconnect / relaunch failure matrix
- production output validation / project-controlled copy assurance
- retention / deletion / cost accounting model
- provider-neutral run manifest
- real-separator differential batch executor
- current-iPhone Moises reference identity fail-closed gate
- reviewer worksheet / acceptance calculator

ただし、以下は未取得でありPARITYはまだ一切主張しない:
- production separator credential / written commercial grant
- rights-cleared G1/G2 real-audio corpus
- live project separator results
- actual provider cost / retention / delete / cancel evidence
- current-iPhone Moises comparison artifacts
- blind human review
- integrated iPhone long-track/background/relaunch/storage/thermal evidence

## 2. 完成定義

### Gate A｜Lane Engineering Complete

Worker 1単独で可能な実装・hardening・tests・evidence preparationがすべて完了し、外部入力が到着したら設計変更なしでlive gateを実行できる状態。

必須条件:
1. production provider routeが実装済み。
2. 2-stem / 4-stem / current referenceで必要なcustom separation modeを表現可能。
3. start / observe / cancel / retry / resume / relaunchの意味論が曖昧でない。
4. duplicate billing / duplicate job / ambiguous network responseを安全に扱う。
5. expiring vendor outputをproject-controlled storageへ検証付きで確保する。
6. partial / corrupt / duplicate / stale / expired outputをfail-closedで扱う。
7. retention / deletion / privacy / cost / quota / rate-limitを追跡できる。
8. long-track向けにupload/downloadをstreamし、disk / memory preflightを行う。
9. full fault matrixが機械実行可能。
10. external live gateをone-commandで再現可能。

### Gate B｜Lane Live Evidence Complete

外部入力を使ったlive evidenceが揃い、Lane 1起因の品質・復旧・privacy・costの重大未確認がない状態。

必須条件:
1. 書面で商用利用可能なproduction route。
2. rights-cleared G1/G2 real-audio corpus。
3. real multi-genre separation output。
4. objective quality metrics。
5. blind listening differential against current-iPhone Moises。
6. actual latency / retry / failure / cost evidence。
7. actual retention / deletion / cancellation semantics evidence。
8. long-track / interruption / relaunch / storage-pressure evidence。
9. Moisesに明白な実用劣位が残らない。

### Gate C｜HQ PARITY Complete

HQが4 Laneを統合し、実iPhone・実音源・cross-feature regressionを行い、`PARITY_MATRIX.json` を更新する。

Worker 1はPARITY_MATRIXを直接変更しない。

## 3. Autonomous Macro Wave Roadmap

1回の「次」につき、以下のWaveを上から優先して1件完遂する。各Waveは `implementation -> negative/edge/recovery -> tests/benchmark -> durable evidence -> commit -> status update` まで行う。

### L1-A05｜v4 Rebaseline / Completion Gap Inventory

Goal:
- 旧`CHECKPOINT_READY`状態をv4自律運用へ再同期し、現在コードとcurrent Reference/PARITYの差分を機械的に棚卸しする。

Work:
- Separation / Processingのcurrent branch API・tests・evidence一覧を再監査。
- P003/P004/P005/P020/P021/P024へのcoverage matrixを作る。
- bootstrap M01-M04で済んだ内容と今後のWaveを重複排除。
- statusへautonomous wave trackingを導入。

Done when:
- 以降のWaveがコード実態と1対1で追跡可能で、旧「HQ task補充待ち」を停止理由にしない。

### L1-A06｜Production Separation Backend Orchestrator

Goal:
- `ServerSeparationProvider`のproject API境界から、実vendor adapterまでを本番server flowとして閉じる。

Work:
- upload -> vendor task creation -> polling -> artifact acquisition -> project manifestのend-to-end orchestration。
- credentialはserver-side environment only。
- stable project/job identity。
- restart-safe server job state。
- output expiry前のproject-controlled copy。

Negative / recovery:
- mid-upload disconnect
- task create timeout
- task polling failure
- process restart
- output URL expiry
- repeated client start

Done when:
- credentialを入れれば実vendorへ接続でき、fake pathなしでproject API契約を満たせる。

### L1-A07｜Idempotency / Duplicate Billing Safety

Goal:
- 同一logical separation requestで二重provider job・二重課金が起きない設計を完成させる。

Work:
- persisted idempotency registry。
- ambiguous POST response recovery。
- same key / same payload = same logical job。
- same key / different payload = fail closed。
- retry after server crash。
- provider-side idempotency有無をcapabilityとして扱う。

Done when:
- network ambiguity / relaunch / repeated tapでもduplicate logical processingが発生しないことをfault testsで証明する。

### L1-A08｜Cancellation Truthfulness / Race Semantics

Goal:
- UI上のcancelとprovider compute cancellationを混同しない。

Work:
- `CLIENT_CANCELLED`
- `POLLING_STOPPED`
- `OUTPUT_DISCARDED`
- `UPSTREAM_CANCEL_CONFIRMED`
を区別。
- providerにauthoritative cancel APIが無い場合は上流compute停止を主張しない。
- ready-vs-cancel raceを定義。
- cancel後retry / relaunchを定義。

Done when:
- cancellation/retry/resumeの状態遷移に虚偽がなく、P020 live testへ投入できる。

### L1-A09｜Retention / Deletion / Privacy Enforcement

Goal:
- user audioとstem artifactの保存・削除・vendor retentionを追跡可能かつfail-closedにする。

Work:
- source upload retention metadata。
- vendor asset/output expiry tracking。
- project copy completed timestamp/hash。
- delete-request state / delete-confirmed state。
- logsからfilename/audio content/API key/vendor secretを除外。
- privacy-safe diagnostic manifest。

Done when:
- providerの実契約値を差し込めばP024に必要なserver-side retention/deletion evidenceが生成できる。

### L1-A10｜Cost / Credit / Quota / Rate-Limit Guard

Goal:
- server separationの予測不能な課金・quota超過を防ぐ。

Work:
- duration x requested targetのestimated cost model。
- actual cost reconciliation field。
- configurable per-job ceiling。
- daily/monthly guard hook。
- 429 / quota / credit exhausted semantics。
- retryでduplicate billingしないことをA07と連携。

Done when:
- live provider pricingを設定するだけでcost evidenceとbudget fail-safeが成立する。

### L1-A11｜Reference Separation Profile Registry

Goal:
- current iPhone Referenceで確認済みの分離modeをprovider-neutralに表現する。

Minimum profiles:
- vocals / instrumental 2-stem
- vocals / drums / bass / other 4-stem
- custom instrument selection
- quality profile / Hi-Fi capability

Work:
- stable profile IDs。
- canonical role mapping。
- unsupported role/profile fail closed。
- profile-specific output completeness validation。
- provider capability negotiation。

Done when:
- app/HQ側がvendor名を知らずにcurrent separation modeを要求できる。

### L1-A12｜Advanced Instrument / Hi-Fi Capability Hardening

Goal:
- P004/P005に必要な追加instrument separationを、実providerのmodel registryへ安全に接続できるようにする。

Work:
- guitar / piano-keys / strings / winds等のcapability representation。
- custom target combination validation。
- max target count / incompatible combination validation。
- Hi-Fi / professional modeのprovider capability mapping。
- output role normalization。

Done when:
- Referenceで追加確認されたinstrument/modeをShared変更なしでLane 1へ追加可能。

### L1-A13｜Audio Artifact Integrity Deep Validation

Goal:
- 「download成功」を「正しいstem」と誤認しない。

Work:
- container sniffing / extension mismatch rejection。
- sample-rate / channel / frame count validation。
- duration/start-time tolerance。
- zero-byte / truncated / corrupt audio rejection。
- unexpected silence / pathological clipping / invalid numeric sample検査を可能な範囲で追加。
- SHA-256 / size / metadata binding。

Done when:
- corrupt/partial/mislabeled vendor outputがproject-visible StemArtifactへ昇格しない。

### L1-A14｜Atomic Multi-Stem Result Transaction

Goal:
- required stemの一部だけが保存された状態でprojectをready扱いしない。

Work:
- per-stem staging。
- full-set validation。
- atomic result promotion。
- relaunch後staging recovery。
- stale staging cleanup。
- one output expiry時のre-fetch / fail semantics。

Done when:
- crash / disk failure / network failureの途中でもproject metadataが不完全resultを指さない。

### L1-A15｜Long-Track Streaming / Storage Pressure Hardening

Goal:
- 長尺音源を全Data化せず、安全にserver処理する。

Work:
- streaming upload/download regression。
- preflight disk requirement estimate。
- staged-copy space accounting。
- large file boundary。
- temporary artifact cleanup。
- backpressure / bounded concurrency。
- phaseごとのbytes/time instrumentation。

Done when:
- lane-local環境で長尺相当の大容量fixtureを使ったmemory/storage stressが成立する。

### L1-A16｜Reconnect / Relaunch Durable Job Registry

Goal:
- app/server再起動後もlogical processing stateを再構築する。

Work:
- jobID / projectID / assetID / requested profile / idempotency key / last authoritative snapshotをdurable化。
- stale cacheよりprovider/server authoritative stateを優先。
- relaunch時にready/cancelled/failedを再同期。
- unknown job / deleted job recovery policy。

Done when:
- simulated terminationを跨いでprocessing lifecycleが破損しない。

### L1-A17｜Full Provider Fault Matrix

Goal:
- live運用で起きるfailure classを網羅し、stable error codeとrecovery actionを固定する。

Minimum cases:
- credential invalid
- 401/403
- 404 job
- 409 conflict
- 413 oversized input
- 429 rate limit
- 5xx
- DNS/TLS failure
- upload timeout
- poll timeout
- malformed JSON
- vendor task error
- missing target
- duplicate target
- expired output URL
- corrupt WAV
- disk full
- local deletion failure
- process crash during each phase

Done when:
- failure matrixが機械実行でき、各caseのretryable/non-retryable/actionが明示される。

### L1-A18｜Privacy-Safe Observability / Evidence Telemetry

Goal:
- PARITY/production debuggingに必要な情報を残しつつuser contentを漏らさない。

Capture:
- phase wall time
- retry count
- bytes transferred
- target count/profile
- stable error code
- cost inputs
- provider/model/version identity
- artifact hashes

Never capture:
- API key/secret
- raw audio
- user media filename when unnecessary
- signed output URL secrets

Done when:
- redaction testsとmachine-readable evidence schemaがPASSする。

### L1-A19｜Golden G1/G2 Corpus Intake Hardening

Goal:
- 実音源受領時に権利不足・coverage不足を自動検出する。

Work:
- rights record validation。
- fixture SHA lock。
- G1/G2 role distinction。
- real/non-synthetic requirement。
- Reference submission permission。
- genre / duration / production coverage。
- final proposal floorとしてG1 12曲 + G2 12曲を検証可能にする。

Done when:
- audioを置くだけでlegal/coverage preflightがPASS/FAILを返し、不適法fixtureをlive gateへ流さない。

### L1-A20｜Differential Gate Resume / Reproducibility Hardening

Goal:
- 既存L1-M04 differential executorを長時間live batch運用に耐えるものへ仕上げる。

Work:
- interrupted batch resume。
- per-case immutable hashes。
- repeated run determinism。
- reviewer assignment stability。
- missing review / replacement review semantics。
- evidence schema versioning。
- acceptance threshold audit trail。

Done when:
- 12+12 corpusのlive differentialを途中再開しても同一case identityと証拠連鎖を維持する。

## 4. External / Human Gate Wave

以下はcredential・権利・実Reference・人間聴感なしには完了できない。ただし、前節のA05〜A20を完了してから初めて外部入力を要求するのではなく、外部入力が先に得られた場合はcritical pathに合わせて前倒ししてよい。

### L1-E01｜Commercial Route Approval / Credential

必要入力:
- AudioShakeまたは同等providerのproduction/evaluation credential。
- intended consumer appでのcommercial useを許す書面/契約。
- retention/deletion/confidentiality/output-use/pricing/region条件。

Acceptance:
- secretはGitHub/iPhone clientへ入れない。
- exact provider/model/version/terms referenceをevidenceへ固定。

### L1-E02｜Rights-Cleared Real Audio Intake

必要入力:
- G1: isolated sourceを持つrights-cleared real multitrack。
- G2: projectとcurrent-iPhone Moises双方へ入力可能なrights-cleared real recording。

Acceptance:
- G1/G2 rights manifestとhashがA19をPASS。
- synthetic-onlyではない。

### L1-E03｜Live Separation Benchmark

実行:
- 2-stem
- core 4-stem
- representative additional/custom instrument modes
- Hi-Fi/advanced mode where current Reference requires it

Measure:
- success/failure
- wall time
- retries
- cost
- output integrity
- SI-SDR / reconstruction where G1 reference stems exist

Acceptance:
- fake/prebakedなし。
- repeated runsが成立。

### L1-E04｜Current-iPhone Moises Differential Listening

実行:
- same/comparable G2 inputをcurrent-iPhone Moisesとprojectへ投入。
- reference assetはrepositoryへコピーしない。
- blind A/B review。

Review dimensions:
- target preservation
- bleed
- musical noise
- transient integrity
- timbre/formant integrity
- stereo/phase integrity
- low-frequency integrity
- reverb/ambience
- practical usability

Acceptance:
- 明白な実用劣位があればPASSしない。

### L1-E05｜Live Processing Recovery / Provider Semantics

実行:
- real network interruption
- cancel during upload / separating / finalizing
- retry after ambiguous failure
- app/server relaunch
- output expiry
- rate limit
- long track
- storage pressure

Acceptance:
- project corruptionなし。
- duplicate billing/jobなし。
- cancellation claimがproviderの実挙動と一致。

### L1-E06｜Provider Route Decision Loop

AudioShake等の候補が品質・cost・privacy・cancellation・latencyで明白に劣る場合、無理に採用しない。

Fallback order:
1. licensed Local Inference SDKが同等品質を提供するか比較。
2. alternate written-commercial providerを同じcontractへ差し替え。
3. rights-cleared training dataが確保できる場合はproject-owned model route。

Provider変更でもA07〜A20のproject-side safety contractを再利用する。

## 5. HQ Late Integration Gate

Worker 1のlive evidence後、HQへ以下を渡す。

Handoff package:
- selected provider/runtime identity
- commercial/rights evidence references
- G1/G2 fixture manifest hashes
- separation run manifests
- objective metric results
- blind review results
- latency/retry/failure/cost evidence
- cancellation semantics evidence
- retention/deletion/privacy evidence
- long-track/storage evidence
- unresolved gaps

HQ responsibility:
- 4 Lane semantic integration
- Shared/App adapter resolution
- actual integrated iOS build
- physical iPhone background/thermal/battery evidence
- cross-feature regression
- final Differential Moises judgment
- PARITY_MATRIX update

## 6. Lane 1 Final Exit Criteria

Lane 1は以下をすべて満たして初めて「完成」と報告する。

1. `Gate A Lane Engineering Complete` = PASS。
2. `Gate B Lane Live Evidence Complete` = PASS。
3. P003/P004/P005/P020にWorker 1起因の未解決重大Gapがない。
4. P021/P024についてLane 1担当部分の実測/evidenceが揃う。
5. provider契約・privacy・retention・deletion・cost条件に未確認の重大事項がない。
6. current-iPhone Moisesとのreal-audio A/Bで明白な品質劣位がない。
7. 失敗・cancel・retry・relaunch・partial resultでproject corruption / duplicate billingがない。
8. HQがintegration/device gateを実行できる完全なhandoff packageがある。
9. synthetic-only / compile-only / harness-only evidenceをPARITYとして扱っていない。
10. PARITY_MATRIXの最終変更はHQに委ねる。

## 7. 実行優先順位

外部credential/real-audioがまだ無い現在は、まず `L1-A05 -> A06 -> A07 -> A08 -> A09 -> A10 -> A11 -> A12 -> A13 -> A14 -> A15 -> A16 -> A17 -> A18 -> A19 -> A20` の順を基本線とする。

ただし毎回の「次」でbranch/status/PARITYを再監査し、前Waveの発見によってcritical pathが変わった場合は順序を再最適化する。filler workは禁止し、必ずcurrent-iPhone PARITY・production safety・live validation readinessのいずれかを前進させる。

このロードマップは有限Taskを消化したら停止するためのものではない。A/Bで差分が見つかった場合は、原因に対応する追加Autonomous Macro Waveを生成し、明白な劣位が消えるまでDifferential Loopを継続する。
