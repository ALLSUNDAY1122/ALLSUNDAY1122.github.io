import Foundation
import Msplat

/// App-local facade over Msplat's trainer that makes SH3 preservation part of reconstruction completion.
///
/// Msplat's legacy `.splat` export stores only DC color. We keep that file for existing viewer/project
/// compatibility, then immediately persist the trainer's full SH3 PLY as a content-addressed canonical asset.
/// If canonical persistence or durable project registration fails, the pending `.splat` is removed so
/// ScanModel's existing completion gate fails instead of silently committing an SH0-only result.
final class SH3PreservingGaussianTrainer {
    private let base: Msplat.GaussianTrainer

    init(dataset: GaussianDataset, config: TrainingConfig = TrainingConfig()) {
        base = Msplat.GaussianTrainer(dataset: dataset, config: config)
    }

    @discardableResult
    func step() -> TrainingStats {
        applyThermalPacingBeforeStep()

        // Build 6 physical evidence showed repeated memory-pressure pauses after a long-running
        // reconstruction pass. Keep each Msplat step inside its own autorelease scope so temporary
        // Objective-C / Metal wrapper objects do not wait for the outer run-level pool to drain.
        // Every twentieth iteration is also the app's resource-sampling cadence; synchronize queued
        // Metal work before returning that sample so the guard measures the settled footprint rather
        // than an in-flight command-buffer high-water mark. This changes lifetime/wall-clock only —
        // no frame, resolution, Gaussian, optimizer, SH or iteration quality contract is reduced.
        return autoreleasepool {
            let stats = base.step()
            if stats.iteration % 20 == 0 {
                msplatSync()
            }
            return stats
        }
    }

    private func applyThermalPacingBeforeStep() {
        let thermalState = ProcessInfo.processInfo.thermalState
        let delay = SplatReconstructionPolicy.thermalPacingDelaySeconds(thermalState)
        guard delay > 0 else { return }

        // At serious pressure, drain queued Metal work before yielding the worker thread so the
        // cooldown interval actually reduces GPU duty-cycle instead of only delaying CPU submission.
        if thermalState == .serious {
            msplatSync()
        }
        Thread.sleep(forTimeInterval: delay)
    }

    func train() {
        base.train()
    }

    func evaluate() -> EvalMetrics {
        base.evaluate()
    }

    func render(cameraIndex: Int, useTest: Bool = false) -> PixelData {
        base.render(cameraIndex: cameraIndex, useTest: useTest)
    }

    func renderFromPose(camToWorld: [Float], refCameraIndex: Int = 0) -> PixelData {
        base.renderFromPose(camToWorld: camToWorld, refCameraIndex: refCameraIndex)
    }

    func renderFromPoseToBuffer(
        camToWorld: [Float],
        refCameraIndex: Int = 0,
        rgba: UnsafeMutablePointer<UInt8>?,
        width: inout Int32,
        height: inout Int32
    ) {
        base.renderFromPoseToBuffer(
            camToWorld: camToWorld,
            refCameraIndex: refCameraIndex,
            rgba: rgba,
            width: &width,
            height: &height
        )
    }

    func exportPly(to path: String) {
        base.exportPly(to: path)
    }

    func exportSplat(to path: String) {
        let legacyURL = URL(fileURLWithPath: path)
        base.exportSplat(to: path)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0,
              size.intValue % 32 == 0 else {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }

        do {
            let asset = try SplatCanonicalSHAsset.persistCollisionSafe(
                from: base,
                legacySplatURL: legacyURL,
                expectedPointCount: size.intValue / 32
            )
            _ = try SplatCanonicalSHAsset.registerDurableProjectOutput(
                asset,
                legacySplatURL: legacyURL
            )
        } catch {
            // ScanModel already treats a missing/invalid pending `.splat` as reconstruction failure.
            // Never delete the canonical target here: collision-safe persistence may have reused an
            // asset that belongs to the previously committed result. A registration failure can leave
            // an orphan candidate, but that is safer than deleting recovery-critical SH3 data.
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    @discardableResult
    func saveCheckpoint(to path: String) -> Bool {
        base.saveCheckpoint(to: path)
    }

    @discardableResult
    func loadCheckpoint(from path: String) -> Int? {
        base.loadCheckpoint(from: path)
    }

    var splatCount: Int { base.splatCount }
    var iteration: Int { base.iteration }
}

/// Shadows the imported Msplat symbol only inside the app module. Existing ScanModel call sites remain
/// unchanged while reconstruction gains the SH3 canonical-asset invariant above.
typealias GaussianTrainer = SH3PreservingGaussianTrainer
