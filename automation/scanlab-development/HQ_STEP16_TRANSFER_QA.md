# STEP16 HQ — post-ownership-transfer independent QA
Date: 2026-10-20 JST.

## Live governance
- Control branch automation/scanlab-hq-control-20261020 HEAD b96837c26877371616502a15f00eaa5408373b01, Queue content SHA ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd.
- SCANLAB-W1-001 owner WORKER_2 CLAIMED epoch2; native lock epoch2 / branch attempt/scanlab-w1-takeover-w2-20261020-a2 / token SCANLAB-W1-001-a2-W2-20261020.
- SCANLAB-W2-001 owner WORKER_2 CLAIMED epoch1 / branch attempt/scanlab-w2-20261020-a1. HQ claim epoch1 unchanged. WORKER_1 STOPPED; no contact.
- Takeover PR #5622 head a050e1fd78deb8094178242c4515aeb2819cb64a; Viewer/Publish PR #5619 head 067902285e71c15af5d53623b66b9d06688d622f. App baseline 2bcbbd6128863739ad168610cd2e3f8e3b01b458.

## Divergent CI on same source commit
- Companion PR #5621 native run 39367475853 SUCCESS, integrated XCTest 245 tests, 0 failures.
- Takeover PR #5622 native run 39367980809 FAILURE, integrated XCTest 245 tests, 2 assertions in one case:
  SplatCompletionVerifierTests.testRestoresTrustedPreviousResultWhenCurrentSameSizeResultFailsStrongIntegrity at lines 162 (completionEvidenceMismatch) and 167 (expected previous backup removed, but still present).
- Both runs declared head a050e1fd78de, yet PR base differs and runner uses GitHub synthetic pull merge; identical head DOES NOT prove identical effective checkout. Inspect event merge checkout SHA and actual test/source blobs before classifying true flakiness.
- Source test simulates trusted previous result restored after same-size modified corrupt new bytes and restored mtime. Existing backup must never be destroyed on integrity failure.
- HQ posted actionable comment #6283324587 on PR #5622 addressed solely to WORKER_2.
- HQ triggered GitHub API re-run of failed jobs for run 39367980809 (success accepted). Rerun result pending; no claim of PASS.

## Release decision
- W2 T37-T39 previous head 26839ecc had Native run 39362812776 PASS 245/0, but latest head 067902285e71 has not been shown to have current-head full native PASS in this STEP.
- Do not merge either branch; do not start Codemagic build, upload, assign TestFlight group, or submit App Review until both task-gated sources and combined T40 pass.
