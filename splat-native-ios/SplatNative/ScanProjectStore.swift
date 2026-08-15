import Foundation

enum ScanProjectStage: String, Codable, CaseIterable {
    case capturing
    case captured
    case processing
    case finished
    case failed
}

enum ScanRepresentationKind: String, Codable, CaseIterable {
    case splat
    case mesh
}

struct ScanProjectManifest: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var stage: ScanProjectStage
    var acceptedFrames: Int
    var targetFrames: Int
    var featurePointCount: Int
    var coverageSectorCount: Int
    var rawDataRetained: Bool
    var outputs: [String: String]
    var thumbnailFileName: String?
    var lastError: String?
    var recoveredAfterInterruption: Bool

    init(
        id: String,
        title: String = "スキャン",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        stage: ScanProjectStage = .capturing,
        acceptedFrames: Int = 0,
        targetFrames: Int = 48,
        featurePointCount: Int = 0,
        coverageSectorCount: Int = 0,
        rawDataRetained: Bool = true,
        outputs: [String: String] = [:],
        thumbnailFileName: String? = nil,
        lastError: String? = nil,
        recoveredAfterInterruption: Bool = false
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stage = stage
        self.acceptedFrames = acceptedFrames
        self.targetFrames = targetFrames
        self.featurePointCount = featurePointCount
        self.coverageSectorCount = coverageSectorCount
        self.rawDataRetained = rawDataRetained
        self.outputs = outputs
        self.thumbnailFileName = thumbnailFileName
        self.lastError = lastError
        self.recoveredAfterInterruption = recoveredAfterInterruption
    }

    var splatFileName: String? { outputs[ScanRepresentationKind.splat.rawValue] }
    var meshFileName: String? { outputs[ScanRepresentationKind.mesh.rawValue] }
}

struct StoredCapturedFrame: Codable, Equatable {
    var id: Int
    var filePath: String
    var transformMatrix: [[Float]]
    var flX: Float
    var flY: Float
    var cx: Float
    var cy: Float
    var w: Int
    var h: Int
}

struct StoredFeaturePoint: Codable, Equatable {
    var id: UInt64
    var x: Float
    var y: Float
    var z: Float
}

struct StoredVector3: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
}

struct ScanCaptureCheckpoint: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var frames: [StoredCapturedFrame]
    var featurePoints: [StoredFeaturePoint]
    var coverageSectors: [Int]
    var estimatedTargetCenter: StoredVector3?
    var lastAcceptedTransform: [[Float]]?
    var lastAcceptedTimestamp: TimeInterval

    init(
        savedAt: Date = Date(),
        frames: [StoredCapturedFrame],
        featurePoints: [StoredFeaturePoint],
        coverageSectors: [Int],
        estimatedTargetCenter: StoredVector3?,
        lastAcceptedTransform: [[Float]]?,
        lastAcceptedTimestamp: TimeInterval
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.savedAt = savedAt
        self.frames = frames
        self.featurePoints = featurePoints
        self.coverageSectors = coverageSectors
        self.estimatedTargetCenter = estimatedTargetCenter
        self.lastAcceptedTransform = lastAcceptedTransform
        self.lastAcceptedTimestamp = lastAcceptedTimestamp
    }
}

struct ScanProjectSummary: Identifiable, Equatable {
    var id: String { manifest.id }
    var manifest: ScanProjectManifest
    var projectURL: URL
    var storageBytes: Int64

    var thumbnailURL: URL? {
        guard let name = manifest.thumbnailFileName else { return nil }
        let url = projectURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var resultURL: URL? {
        guard let name = manifest.splatFileName else { return nil }
        let url = projectURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

struct ScanReprocessRequest: Equatable {
    var projectID: String
    var projectURL: URL
    var representation: ScanRepresentationKind
    var transformsURL: URL
    var pointCloudURL: URL
    var imagesURL: URL
}

enum ScanProjectStoreError: LocalizedError {
    case projectNotFound
    case rawDataUnavailable
    case invalidManifest
    case invalidPendingResult

    var errorDescription: String? {
        switch self {
        case .projectNotFound: return "保存済みスキャンが見つかりません"
        case .rawDataUnavailable: return "再処理に必要なrawデータがありません"
        case .invalidManifest: return "スキャン情報を読み込めません"
        case .invalidPendingResult: return "生成結果の安全な保存を完了できません"
        }
    }
}

/// File-system source of truth for local scans.
/// Every project is self-contained so the library can be rebuilt after termination without an in-memory index.
final class ScanProjectStore {
    static let projectExtension = "splatproject"
    static let manifestFileName = "manifest.json"
    static let manifestBackupFileName = "manifest.json.bak"
    static let checkpointFileName = "capture-checkpoint.plist"
    static let checkpointBackupFileName = "capture-checkpoint.plist.bak"
    static let worldMapFileName = "worldmap.arexperience"
    static let thumbnailFileName = "thumbnail.jpg"
    static let splatResultFileName = "result.splat"
    static let pendingSplatFileName = "result.pending.splat"
    static let previousSplatFileName = "result.previous.splat"
    static let trashDirectoryName = ".Trash"

    let rootURL: URL
    let trashURL: URL
    private let fileManager: FileManager

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            self.rootURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SplatLab", isDirectory: true)
        }
        self.trashURL = self.rootURL.appendingPathComponent(Self.trashDirectoryName, isDirectory: true)
        try? ensureDirectories()
    }

    @discardableResult
    func createProject(title: String = "スキャン", targetFrames: Int = 48) throws -> (URL, ScanProjectManifest) {
        try ensureDirectories()
        let id = UUID().uuidString
        let projectURL = rootURL.appendingPathComponent(id).appendingPathExtension(Self.projectExtension)
        try fileManager.createDirectory(
            at: projectURL.appendingPathComponent("images", isDirectory: true),
            withIntermediateDirectories: true
        )
        var manifest = ScanProjectManifest(id: id, title: title, targetFrames: targetFrames)
        manifest.updatedAt = Date()
        try writeManifest(manifest, to: projectURL)
        return (projectURL, manifest)
    }

    func listProjects() -> [ScanProjectSummary] {
        (try? summaries(in: rootURL, includeHidden: false)) ?? []
    }

    func listTrash() -> [ScanProjectSummary] {
        (try? summaries(in: trashURL, includeHidden: true)) ?? []
    }

    func loadProject(id: String) throws -> ScanProjectSummary {
        let url = projectURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { throw ScanProjectStoreError.projectNotFound }
        let manifest = try loadOrMigrateManifest(projectURL: url)
        let repaired = try repairIfNeeded(manifest: manifest, projectURL: url)
        return ScanProjectSummary(manifest: repaired, projectURL: url, storageBytes: directorySize(url))
    }

    func loadManifest(projectURL: URL) throws -> ScanProjectManifest {
        try repairIfNeeded(manifest: loadOrMigrateManifest(projectURL: projectURL), projectURL: projectURL)
    }

    func updateManifest(projectURL: URL, _ mutate: (inout ScanProjectManifest) -> Void) throws -> ScanProjectManifest {
        var manifest = try loadOrMigrateManifest(projectURL: projectURL)
        let previousStage = manifest.stage
        mutate(&manifest)
        manifest.schemaVersion = ScanProjectManifest.currentSchemaVersion
        manifest.updatedAt = Date()
        try writeManifest(manifest, to: projectURL)

        if manifest.stage == .processing, previousStage != .processing {
            preparePriorSplatForProcessing(projectURL: projectURL)
        } else if manifest.stage == .finished {
            cleanupSplatSwapArtifacts(projectURL: projectURL)
        }
        return manifest
    }

    func writeManifest(_ manifest: ScanProjectManifest, to projectURL: URL) throws {
        let primary = projectURL.appendingPathComponent(Self.manifestFileName)
        let backup = projectURL.appendingPathComponent(Self.manifestBackupFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try rotateBackup(primary: primary, backup: backup)
        try data.write(to: primary, options: .atomic)
    }

    func saveCheckpoint(_ checkpoint: ScanCaptureCheckpoint, projectURL: URL) throws {
        let primary = projectURL.appendingPathComponent(Self.checkpointFileName)
        let backup = projectURL.appendingPathComponent(Self.checkpointBackupFileName)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(checkpoint)
        try rotateBackup(primary: primary, backup: backup)
        try data.write(to: primary, options: .atomic)
    }

    func loadCheckpoint(projectURL: URL) throws -> ScanCaptureCheckpoint {
        let primary = projectURL.appendingPathComponent(Self.checkpointFileName)
        let backup = projectURL.appendingPathComponent(Self.checkpointBackupFileName)
        let decoder = PropertyListDecoder()
        if let data = try? Data(contentsOf: primary),
           let value = try? decoder.decode(ScanCaptureCheckpoint.self, from: data) {
            return value
        }
        if let data = try? Data(contentsOf: backup),
           let value = try? decoder.decode(ScanCaptureCheckpoint.self, from: data) {
            try? data.write(to: primary, options: .atomic)
            return value
        }
        throw ScanProjectStoreError.rawDataUnavailable
    }

    func setThumbnail(from sourceURL: URL, projectURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        let target = projectURL.appendingPathComponent(Self.thumbnailFileName)
        if sourceURL.standardizedFileURL != target.standardizedFileURL {
            try Data(contentsOf: sourceURL).write(to: target, options: .atomic)
        }
        _ = try updateManifest(projectURL: projectURL) { $0.thumbnailFileName = Self.thumbnailFileName }
    }

    func setThumbnail(data: Data, projectURL: URL) throws {
        let target = projectURL.appendingPathComponent(Self.thumbnailFileName)
        try data.write(to: target, options: .atomic)
        _ = try updateManifest(projectURL: projectURL) { $0.thumbnailFileName = Self.thumbnailFileName }
    }

    func reprocessRequest(projectURL: URL, representation: ScanRepresentationKind) throws -> ScanReprocessRequest {
        let images = projectURL.appendingPathComponent("images", isDirectory: true)
        let transforms = projectURL.appendingPathComponent("transforms.json")
        let points = projectURL.appendingPathComponent("points3D.ply")
        guard fileManager.fileExists(atPath: images.path),
              fileManager.fileExists(atPath: transforms.path),
              fileManager.fileExists(atPath: points.path) else {
            throw ScanProjectStoreError.rawDataUnavailable
        }
        return ScanReprocessRequest(
            projectID: projectURL.deletingPathExtension().lastPathComponent,
            projectURL: projectURL,
            representation: representation,
            transformsURL: transforms,
            pointCloudURL: points,
            imagesURL: images
        )
    }

    /// Optional two-phase writer for reconstruction engines that can export to a temporary path.
    func commitPendingSplat(projectURL: URL) throws -> URL {
        let pending = projectURL.appendingPathComponent(Self.pendingSplatFileName)
        let output = projectURL.appendingPathComponent(Self.splatResultFileName)
        let previous = projectURL.appendingPathComponent(Self.previousSplatFileName)
        guard validSplat(at: pending) else { throw ScanProjectStoreError.invalidPendingResult }

        if fileManager.fileExists(atPath: output.path) {
            if fileManager.fileExists(atPath: previous.path) { try fileManager.removeItem(at: previous) }
            try fileManager.moveItem(at: output, to: previous)
        }
        do {
            if fileManager.fileExists(atPath: output.path) { try fileManager.removeItem(at: output) }
            try fileManager.moveItem(at: pending, to: output)
            guard validSplat(at: output) else { throw ScanProjectStoreError.invalidPendingResult }
        } catch {
            if !fileManager.fileExists(atPath: output.path), fileManager.fileExists(atPath: previous.path) {
                try? fileManager.moveItem(at: previous, to: output)
            }
            throw error
        }
        if fileManager.fileExists(atPath: previous.path) { try? fileManager.removeItem(at: previous) }
        return output
    }

    func clearRawData(projectURL: URL) throws {
        let manifest = try loadOrMigrateManifest(projectURL: projectURL)
        let resultNames = Set(manifest.outputs.values)
        let keep = resultNames.union([
            Self.manifestFileName,
            Self.manifestBackupFileName,
            Self.thumbnailFileName
        ])
        let children = try fileManager.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
        for child in children where !keep.contains(child.lastPathComponent) {
            try? fileManager.removeItem(at: child)
        }
        _ = try updateManifest(projectURL: projectURL) { $0.rawDataRetained = false }
    }

    func moveToTrash(projectURL: URL) throws {
        try ensureDirectories()
        let destination = trashURL.appendingPathComponent(projectURL.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: projectURL, to: destination)
    }

    func restoreFromTrash(id: String) throws {
        try ensureDirectories()
        let source = trashURL.appendingPathComponent(id).appendingPathExtension(Self.projectExtension)
        guard fileManager.fileExists(atPath: source.path) else { throw ScanProjectStoreError.projectNotFound }
        var restoredID = id
        var destination = rootURL.appendingPathComponent(restoredID).appendingPathExtension(Self.projectExtension)
        if fileManager.fileExists(atPath: destination.path) {
            restoredID = UUID().uuidString
            destination = rootURL.appendingPathComponent(restoredID).appendingPathExtension(Self.projectExtension)
        }
        try fileManager.moveItem(at: source, to: destination)
        if restoredID != id {
            _ = try updateManifest(projectURL: destination) { $0.id = restoredID }
        }
    }

    func permanentlyDeleteFromTrash(id: String) throws {
        let url = trashURL.appendingPathComponent(id).appendingPathExtension(Self.projectExtension)
        guard fileManager.fileExists(atPath: url.path) else { throw ScanProjectStoreError.projectNotFound }
        try fileManager.removeItem(at: url)
    }

    func storageBytes(includeTrash: Bool = true) -> Int64 {
        var total = directorySize(rootURL)
        if !includeTrash { total -= directorySize(trashURL) }
        return max(0, total)
    }

    func projectURL(for id: String) -> URL {
        rootURL.appendingPathComponent(id).appendingPathExtension(Self.projectExtension)
    }

    func worldMapURL(projectURL: URL) -> URL {
        projectURL.appendingPathComponent(Self.worldMapFileName)
    }

    func hasWorldMap(projectURL: URL) -> Bool {
        fileManager.fileExists(atPath: worldMapURL(projectURL: projectURL).path)
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true)
    }

    private func summaries(in directory: URL, includeHidden: Bool) throws -> [ScanProjectSummary] {
        try ensureDirectories()
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )
        var values: [ScanProjectSummary] = []
        for url in urls where url.pathExtension == Self.projectExtension {
            guard let manifest = try? loadOrMigrateManifest(projectURL: url),
                  let repaired = try? repairIfNeeded(manifest: manifest, projectURL: url) else { continue }
            values.append(ScanProjectSummary(manifest: repaired, projectURL: url, storageBytes: directorySize(url)))
        }
        return values.sorted { $0.manifest.updatedAt > $1.manifest.updatedAt }
    }

    private func loadOrMigrateManifest(projectURL: URL) throws -> ScanProjectManifest {
        let primary = projectURL.appendingPathComponent(Self.manifestFileName)
        let backup = projectURL.appendingPathComponent(Self.manifestBackupFileName)
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: primary),
           let manifest = try? decoder.decode(ScanProjectManifest.self, from: data) {
            return manifest
        }
        if let data = try? Data(contentsOf: backup),
           let manifest = try? decoder.decode(ScanProjectManifest.self, from: data) {
            try? data.write(to: primary, options: .atomic)
            return manifest
        }

        guard fileManager.fileExists(atPath: projectURL.path) else { throw ScanProjectStoreError.projectNotFound }
        let id = projectURL.deletingPathExtension().lastPathComponent
        let attrs = try? fileManager.attributesOfItem(atPath: projectURL.path)
        let createdAt = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? Date()
        let imagesDirectory = projectURL.appendingPathComponent("images", isDirectory: true)
        let imageURLs = ((try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let hasTransforms = fileManager.fileExists(atPath: projectURL.appendingPathComponent("transforms.json").path)
        let hasPoints = fileManager.fileExists(atPath: projectURL.appendingPathComponent("points3D.ply").path)
        let resultURL = projectURL.appendingPathComponent(Self.splatResultFileName)
        let hasResult = validSplat(at: resultURL)
        let stage: ScanProjectStage = hasResult ? .finished : ((hasTransforms && hasPoints) ? .captured : .capturing)
        var outputs: [String: String] = [:]
        if hasResult { outputs[ScanRepresentationKind.splat.rawValue] = resultURL.lastPathComponent }
        var manifest = ScanProjectManifest(
            id: id,
            title: "保存済みスキャン",
            createdAt: createdAt,
            updatedAt: (attrs?[.modificationDate] as? Date) ?? createdAt,
            stage: stage,
            acceptedFrames: imageURLs.count,
            rawDataRetained: !imageURLs.isEmpty,
            outputs: outputs
        )
        if let firstImage = imageURLs.first {
            let thumbnail = projectURL.appendingPathComponent(Self.thumbnailFileName)
            if !fileManager.fileExists(atPath: thumbnail.path), let data = try? Data(contentsOf: firstImage) {
                try? data.write(to: thumbnail, options: .atomic)
            }
            if fileManager.fileExists(atPath: thumbnail.path) { manifest.thumbnailFileName = Self.thumbnailFileName }
        }
        try writeManifest(manifest, to: projectURL)
        return manifest
    }

    private func repairIfNeeded(manifest input: ScanProjectManifest, projectURL: URL) throws -> ScanProjectManifest {
        var manifest = input
        var changed = false
        let output = projectURL.appendingPathComponent(Self.splatResultFileName)
        let previous = projectURL.appendingPathComponent(Self.previousSplatFileName)

        if manifest.stage == .processing {
            let hadPriorResult = manifest.splatFileName != nil
            let recovery = try recoverProcessingResult(projectURL: projectURL)
            if let recoveredURL = recovery.url {
                manifest.outputs[ScanRepresentationKind.splat.rawValue] = recoveredURL.lastPathComponent
                manifest.stage = .finished
                manifest.recoveredAfterInterruption = true
                manifest.lastError = recovery.message ?? (hadPriorResult ? "再生成は中断しましたが、完成済み3Dは保持されています。" : nil)
                changed = true
            } else {
                let canRetry = (try? reprocessRequest(projectURL: projectURL, representation: .splat)) != nil
                manifest.stage = canRetry ? .captured : .failed
                manifest.recoveredAfterInterruption = true
                manifest.lastError = canRetry
                    ? "前回の3D生成は途中で終了しました。rawデータから生成を再開できます。"
                    : "前回の3D生成は途中で終了し、再処理に必要なrawデータも見つかりません。"
                changed = true
            }
        } else if validSplat(at: output) {
            if manifest.splatFileName == nil {
                manifest.outputs[ScanRepresentationKind.splat.rawValue] = output.lastPathComponent
                changed = true
            }
            if manifest.stage == .captured || manifest.stage == .failed {
                manifest.stage = .finished
                changed = true
            }
        } else if validSplat(at: previous) {
            if fileManager.fileExists(atPath: output.path) { try? fileManager.removeItem(at: output) }
            try fileManager.moveItem(at: previous, to: output)
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = output.lastPathComponent
            manifest.stage = .finished
            manifest.recoveredAfterInterruption = true
            if manifest.lastError == nil {
                manifest.lastError = "再生成中断後、以前の完成済み3Dを復元しました。"
            }
            changed = true
        }

        let checkpointPrimary = projectURL.appendingPathComponent(Self.checkpointFileName)
        let checkpointBackup = projectURL.appendingPathComponent(Self.checkpointBackupFileName)
        let rawExists = (try? reprocessRequest(projectURL: projectURL, representation: .splat)) != nil
            || fileManager.fileExists(atPath: checkpointPrimary.path)
            || fileManager.fileExists(atPath: checkpointBackup.path)
        if manifest.rawDataRetained != rawExists {
            manifest.rawDataRetained = rawExists
            changed = true
        }
        if manifest.schemaVersion != ScanProjectManifest.currentSchemaVersion {
            manifest.schemaVersion = ScanProjectManifest.currentSchemaVersion
            changed = true
        }
        if changed {
            manifest.updatedAt = Date()
            try writeManifest(manifest, to: projectURL)
        }
        return manifest
    }

    private func preparePriorSplatForProcessing(projectURL: URL) {
        let output = projectURL.appendingPathComponent(Self.splatResultFileName)
        let previous = projectURL.appendingPathComponent(Self.previousSplatFileName)
        let pending = projectURL.appendingPathComponent(Self.pendingSplatFileName)
        if fileManager.fileExists(atPath: pending.path) { try? fileManager.removeItem(at: pending) }
        guard validSplat(at: output) else { return }
        if fileManager.fileExists(atPath: previous.path) { try? fileManager.removeItem(at: previous) }
        try? fileManager.moveItem(at: output, to: previous)
    }

    private func cleanupSplatSwapArtifacts(projectURL: URL) {
        let output = projectURL.appendingPathComponent(Self.splatResultFileName)
        guard validSplat(at: output) else { return }
        let previous = projectURL.appendingPathComponent(Self.previousSplatFileName)
        let pending = projectURL.appendingPathComponent(Self.pendingSplatFileName)
        if fileManager.fileExists(atPath: previous.path) { try? fileManager.removeItem(at: previous) }
        if fileManager.fileExists(atPath: pending.path) { try? fileManager.removeItem(at: pending) }
    }

    private func recoverProcessingResult(projectURL: URL) throws -> (url: URL?, message: String?) {
        let pending = projectURL.appendingPathComponent(Self.pendingSplatFileName)
        let output = projectURL.appendingPathComponent(Self.splatResultFileName)
        let previous = projectURL.appendingPathComponent(Self.previousSplatFileName)
        if validSplat(at: pending) {
            do { return (try commitPendingSplat(projectURL: projectURL), nil) } catch { }
        }
        if validSplat(at: output) {
            if fileManager.fileExists(atPath: pending.path) { try? fileManager.removeItem(at: pending) }
            if fileManager.fileExists(atPath: previous.path) { try? fileManager.removeItem(at: previous) }
            return (output, nil)
        }
        if validSplat(at: previous) {
            if fileManager.fileExists(atPath: output.path) { try? fileManager.removeItem(at: output) }
            try fileManager.moveItem(at: previous, to: output)
            if fileManager.fileExists(atPath: pending.path) { try? fileManager.removeItem(at: pending) }
            return (output, "再生成は中断しましたが、以前の完成済み3Dを復元しました。")
        }
        return (nil, nil)
    }

    private func rotateBackup(primary: URL, backup: URL) throws {
        guard fileManager.fileExists(atPath: primary.path) else { return }
        if fileManager.fileExists(atPath: backup.path) { try? fileManager.removeItem(at: backup) }
        try fileManager.copyItem(at: primary, to: backup)
    }

    private func validSplat(at url: URL) -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return false }
        return size.int64Value > 0 && size.int64Value % 32 == 0
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           (attrs[.type] as? FileAttributeType) == .typeRegular,
           let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}