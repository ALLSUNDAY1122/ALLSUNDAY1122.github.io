# STEP23 — Verified integration and release-source blocker
2026-10-21 JST. Release HOLD until artifact source provenance fixed.

## Product integration
PR #5624 MERGED (merge commit 01b08971a313045b3e5dc4aec79cc19d47ad1c38). Product branch feature/splat-native-ios-poc HEAD 69f365816bb1ae61a558f40778279b507bd705d6. Latest Native iOS run 39444336078 SUCCESS and aligned privacy, smoke, S9, S10, S12, S13, S14 jobs SUCCESS. This verifies CI on product branch, not signed IPA or Apple upload.

## Release-source blocker
Codemagic scanlab-ios workflow lives in codemagic.yaml on release/scanlab-testflight, not in codemagic.yaml on product branch. Current pinned S16 release gateway validates branch release/scanlab-testflight and builds only that branch; S21 materialize workflow also checks out and pushes to that release branch.
Release/scanlab-testflight HEAD 3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a and product HEAD 69f365816bb1ae61a558f40778279b507bd705d6 have diverged (GitHub compare: product ahead1530, release behind7 in commit graph; 227 file changes in compare). Unsafe to assume release contains Round3 changes or simply merge massive unrelated site changes.
Explicit file provenance: ScanModel.swift product SHA1ee09c07d8cd87cb81165f1c4514211b432fbce5 vs release SHA99deb54ed747ba43119cd0e813ca15e4bda24d97; ScanLabBackend+TrustedPublish.swift product SHAf490f855ef6e16328abd3469790b4f40e8ace5d5 vs release SHAe7b586c30335775235b6a1afc4117811befde7aa; SplatPreviousResultIntegrityRecovery.swift exists in product SHA c5a0981b467aa0421f4dc6c433b4da9912910475 and is missing on release.

## Action and safety
Do NOT write automation/scanlab-release-request.json action=build on product while gateway targets stale release branch. It would build wrong product. No Codemagic app build started, no Apple upload, no Internal TestFlight assignment readback, no App Review submission.
Before launch: prepare isolated release-source synchronization (only splat-native-ios + release config, no wholesale 1530-commit cross-merge), preserve existing signing and Xcode26 SDK requirements; verify every Round3 source hash or a manifest of source hashes, then run native release/preflight checks on synchronized source; use fresh ASC readback to allocate unique next build and upload once; verify Internal TestFlight group read-back.
Queue control must be re-read before any mutation; Worker1 stopped, Worker2 owns both implementation tasks; HQ governance lock only for release.

## Next
Safe separate release-source PR and merge after exact source parity + signing check, then targeted Codemagic build/Apple readback.