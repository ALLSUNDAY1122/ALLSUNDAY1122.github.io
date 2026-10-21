# HQ2 STEP43 — Manual CI dispatch gate

Date: 2026-10-21 JST
State: BLOCKED_NEEDS_HUMAN / RELEASE NO-GO

## Independent remote checks
- Native validation PR #5640: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/5640
- Exact validation branch: `attempt/scanlab-w2-step41-native-ci-20261021-a3`, SHA `a6de3b0918da24fe62532f8ed7f396afa8c446f1`.
- GitHub Native CI run lookup on that SHA: empty; NOT CERTIFIED.
- Worker2 ongoing recovery branch: `attempt/scanlab-w2-recovery-step37-20261021-a2`, HEAD `a02e45b06a9ea1e0bcd0d9274902c9a256ad0e2d`, since earlier `2e31ce1ffdca2a821c3876265941591d81e81f4d` only evidence markdown was modified.
- Worker2 base: `6046660061b25efec0029b9ee9b95c7af19d3a7d`, not integrated with recovery branch.
- Worker2 evidence `W2_STEP38_NATIVE_RECOVERY_EVIDENCE.md` STEP43 says NO exact SHA CI and requests manual GitHub Actions workflow_dispatch.
- Queue last confirmed SHA ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd; Worker2 Native epoch2 and Viewer epoch1 retained; Worker1 permanently stopped.

## Single human operation required
Visit https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/workflows/splat-native-ios.yml
Click Run workflow, select branch `attempt/scanlab-w2-step41-native-ci-20261021-a3`, then confirm Run workflow. This performs Native CI only; not release or upload.

## Gate after dispatch
HQ verifies resulting workflow's head_sha exactly `a6de3b0918da24fe62532f8ed7f396afa8c446f1`, completed/success, full XCTest count and zero failures. Then Worker2 must reconcile base 6-only commits with repair, produce a single combined native SHA, and run full CI on that combined source. Historical run #39533009521 (248 tests/zero fail, old SHA 525fc662) is not accepted as proof.

Release candidate, product, release branch, Codemagic, App Store Connect and Internal TestFlight untouched. NO-GO.
