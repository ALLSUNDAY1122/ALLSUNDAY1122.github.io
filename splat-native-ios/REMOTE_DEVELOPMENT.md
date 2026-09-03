# Scaniverse remote development flow

## Purpose

Keep one persistent Git worktree and use GitHub as the normal build/test environment. Source is pushed frequently, but an IPA is uploaded to TestFlight only for an explicit physical-device checkpoint.

## Persistent checkout

- Development branch: `codex/scaniverse-remote-dev`
- Starting point: `scaniverse/s14d-durability-recovery`
- Do not develop directly on `feature/splat-native-ios-poc`, S14, S14D, or a `testflight/*` branch.
- Do not merge PR #4145, #4836, or #4852 until the physical parity gate says to do so.

On the current Windows machine the persistent worktree is:

```text
C:\Users\PC\Documents\アプリ開発\scaniverse-remote
```

The checkout remains in place between sessions. There is no need to download a ZIP or upload the whole project again.

## Normal edit loop

```powershell
cd 'C:\Users\PC\Documents\アプリ開発\scaniverse-remote'
pwsh -File .\splat-native-ios\scripts\remote_dev.ps1 Sync
# edit files
pwsh -File .\splat-native-ios\scripts\remote_dev.ps1 Check
git add <files>
git commit -m '...'
pwsh -File .\splat-native-ios\scripts\remote_dev.ps1 Push
```

Each development push runs `Scaniverse Remote Dev Fast Gate` on Linux. It checks reconstruction, persistence, memory, S13/S14 seed, S14D materialization, and diff hygiene. It does not build an IPA and does not contact App Store Connect.

## Full iOS checkpoint

When a coherent batch is ready for Xcode validation:

```powershell
pwsh -File .\splat-native-ios\scripts\remote_dev.ps1 DeviceCheck
```

This manually dispatches `Splat Native iOS Build` on GitHub's macOS runner. It performs XcodeGen, SwiftPM resolution, Simulator/XCTest checks, reader compatibility, and unsigned iPhone compilation. It still does not upload to TestFlight.

Opening or updating a pull request also runs the full macOS gate. Ordinary pushes to the development branch do not.

## Physical-device / TestFlight checkpoint

TestFlight is intentionally a separate release operation:

1. Require the fast gate and manually dispatched macOS/Xcode gate to pass on the exact development SHA.
2. Create a new `testflight/splat-native-ios-YYYYMMDD-buildNN` branch from that exact SHA.
3. Change only the release `codemagic.yaml` configuration and build number.
4. Review the diff against the development SHA; app-source drift must be zero.
5. Explicitly start the signed Codemagic workflow.
6. Confirm `submit_to_testflight: true`, `submit_to_app_store: false`, and internal-testing-only before upload.
7. Verify App Store Connect read-back, then perform the real-iPhone test without deleting the app.

Never configure Codemagic automatic builds for `codex/scaniverse-*`. A normal development push must not create or upload an IPA.

## Current release reference

Build 14 already exists as `testflight/splat-native-ios-20260903-build14` at `7b1d36bcb9db63926d12ed6a380cb2224584f0af`. Its only change from S14D is `codemagic.yaml`. Treat it as a release reference, not a development branch.

