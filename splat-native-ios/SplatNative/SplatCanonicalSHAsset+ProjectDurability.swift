import Foundation

extension SplatCanonicalSHAsset {
    static let manifestOutputKeyPrefix = "splatSH3Canonical."

    /// Registers a canonical SH asset as a durable project output before reconstruction completion.
    ///
    /// Keys are content-addressed rather than singular so a failed reprocess cannot evict the canonical
    /// asset belonging to the previously committed `.splat`. `ScanProjectStore.clearRawData()` already
    /// preserves every `manifest.outputs` value, so both the current and recovery candidate remain safe.
    /// HQ may garbage-collect superseded canonical generations after successful integration/physical gates.
    @discardableResult
    static func registerDurableProjectOutput(
        _ asset: Asset,
        legacySplatURL: URL,
        store: ScanProjectStore = ScanProjectStore()
    ) throws -> ScanProjectManifest {
        let projectURL = legacySplatURL.deletingLastPathComponent()
        let key = manifestOutputKeyPrefix + asset.url.deletingPathExtension().lastPathComponent
        return try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.outputs[key] = asset.url.lastPathComponent
        }
    }
}
