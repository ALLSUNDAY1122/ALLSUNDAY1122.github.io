import Foundation

public struct Lane2ManagedArtifactCensusReport: Hashable, Sendable {
    public let generation: Int
    public let scannedRegularFiles: Int
    public let registeredThisPass: Int
    public let generationCompleted: Bool
    public let verificationMatchedPrevious: Bool
    public let authorityPromoted: Bool
    public let registrationLimit: Int
    public let nextRelativePath: String?

    public init(
        generation: Int,
        scannedRegularFiles: Int,
        registeredThisPass: Int,
        generationCompleted: Bool,
        verificationMatchedPrevious: Bool,
        authorityPromoted: Bool,
        registrationLimit: Int,
        nextRelativePath: String?
    ) {
        self.generation = generation
        self.scannedRegularFiles = scannedRegularFiles
        self.registeredThisPass = registeredThisPass
        self.generationCompleted = generationCompleted
        self.verificationMatchedPrevious = verificationMatchedPrevious
        self.authorityPromoted = authorityPromoted
        self.registrationLimit = max(registrationLimit, 1)
        self.nextRelativePath = nextRelativePath
    }
}

public enum Lane2ManagedArtifactCensusFailure: Error, Equatable, Sendable {
    case corruptState
    case unsafeManagedRoot(String)
    case symlinkEncountered(String)
    case enumerationFailed(String)
    case candidateEscapedManagedRoots(String)
}

private struct Lane2ManagedArtifactCensusState: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let generation: Int
    let afterRelativePath: String?
    let rollingHash: UInt64
    let entryCount: Int
    let previousCompletedHash: UInt64?
    let previousCompletedCount: Int?
}

private struct Lane2ManagedArtifactCensusCandidate: Hashable, Sendable {
    let relativePath: String
    let modificationMicros: Int64
    let byteCount: Int64
}

/// One-time upgrade/reconciliation census that incrementally seeds the AW29 sharded inventory.
///
/// Foundation does not provide a durable cross-process directory-enumerator cookie, so this type does
/// not claim O(1) raw directory resumption for arbitrary pre-existing flat directories. Instead it
/// bounds registration work, persists a lexical checkpoint and rolling digest, and requires two
/// consecutive complete generations with identical path/mtime/size digests before inventory authority
/// is granted. A process kill repeats at most the current chunk; directory mutation prevents promotion.
public struct Lane2ManagedArtifactCompatibilityCensus: Sendable {
    public static let defaultRegistrationLimit = 128

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    @discardableResult
    public func advance(
        registrationLimit: Int = Self.defaultRegistrationLimit
    ) throws -> Lane2ManagedArtifactCensusReport {
        let inventory = Lane2ManagedArtifactInventory(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
        if inventory.hasValidAuthoritativeMarker {
            try removeStateIfPresent()
            return Lane2ManagedArtifactCensusReport(
                generation: 0,
                scannedRegularFiles: 0,
                registeredThisPass: 0,
                generationCompleted: true,
                verificationMatchedPrevious: true,
                authorityPromoted: false,
                registrationLimit: registrationLimit,
                nextRelativePath: nil
            )
        }

        let effectiveLimit = max(registrationLimit, 1)
        let state = try loadState() ?? Self.initialState()
        let scan = try scan(afterRelativePath: state.afterRelativePath, limit: effectiveLimit)

        // Register filesystem snapshots before advancing the durable checkpoint. A crash after any
        // shard write but before state persistence simply repeats this idempotent chunk.
        try inventory.registerManaged(relativePaths: scan.selected.map(\.relativePath))

        var rollingHash = state.rollingHash
        var entryCount = state.entryCount
        for candidate in scan.selected {
            rollingHash = Self.mix(rollingHash, candidate: candidate)
            entryCount += 1
        }

        if scan.hasMore {
            let next = scan.selected.last?.relativePath
            try persistState(
                Lane2ManagedArtifactCensusState(
                    schemaVersion: Lane2ManagedArtifactCensusState.schemaVersion,
                    generation: state.generation,
                    afterRelativePath: next,
                    rollingHash: rollingHash,
                    entryCount: entryCount,
                    previousCompletedHash: state.previousCompletedHash,
                    previousCompletedCount: state.previousCompletedCount
                )
            )
            return Lane2ManagedArtifactCensusReport(
                generation: state.generation,
                scannedRegularFiles: scan.scannedRegularFiles,
                registeredThisPass: scan.selected.count,
                generationCompleted: false,
                verificationMatchedPrevious: false,
                authorityPromoted: false,
                registrationLimit: effectiveLimit,
                nextRelativePath: next
            )
        }

        let matched = state.previousCompletedHash == rollingHash
            && state.previousCompletedCount == entryCount
        if matched {
            // Authority is written only after two complete stable generations. The inventory remains
            // deletion-nonauthoritative until this exact atomic marker write succeeds.
            try inventory.markAuthoritativeAfterCompatibilityCensus()
            try removeStateIfPresent()
            return Lane2ManagedArtifactCensusReport(
                generation: state.generation,
                scannedRegularFiles: scan.scannedRegularFiles,
                registeredThisPass: scan.selected.count,
                generationCompleted: true,
                verificationMatchedPrevious: true,
                authorityPromoted: true,
                registrationLimit: effectiveLimit,
                nextRelativePath: nil
            )
        }

        // Start a second (or later) complete generation from the beginning. Any insertion, removal,
        // rename, mtime or size mutation changes the digest and therefore requires another stable pass.
        try persistState(
            Lane2ManagedArtifactCensusState(
                schemaVersion: Lane2ManagedArtifactCensusState.schemaVersion,
                generation: state.generation + 1,
                afterRelativePath: nil,
                rollingHash: Self.offsetBasis,
                entryCount: 0,
                previousCompletedHash: rollingHash,
                previousCompletedCount: entryCount
            )
        )
        return Lane2ManagedArtifactCensusReport(
            generation: state.generation,
            scannedRegularFiles: scan.scannedRegularFiles,
            registeredThisPass: scan.selected.count,
            generationCompleted: true,
            verificationMatchedPrevious: false,
            authorityPromoted: false,
            registrationLimit: effectiveLimit,
            nextRelativePath: nil
        )
    }

    private struct ScanResult {
        let selected: [Lane2ManagedArtifactCensusCandidate]
        let scannedRegularFiles: Int
        let hasMore: Bool
    }

    private func scan(afterRelativePath: String?, limit: Int) throws -> ScanResult {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        var selected: [Lane2ManagedArtifactCensusCandidate] = []
        var scannedRegularFiles = 0

        for rootName in Lane2ManagedArtifactInventory.managedRootNames.sorted() {
            let managedRoot = rootURL.appendingPathComponent(rootName, isDirectory: true)
            guard fileManager.fileExists(atPath: managedRoot.path) else { continue }
            let rootValues = try managedRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
                throw Lane2ManagedArtifactCensusFailure.unsafeManagedRoot(rootName)
            }

            var enumerationFailed = false
            guard let enumerator = fileManager.enumerator(
                at: managedRoot,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in
                    enumerationFailed = true
                    return false
                }
            ) else {
                throw Lane2ManagedArtifactCensusFailure.enumerationFailed(rootName)
            }

            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    throw Lane2ManagedArtifactCensusFailure.symlinkEncountered(
                        try relativePath(for: url)
                    )
                }
                guard values.isRegularFile == true else { continue }
                scannedRegularFiles += 1
                let relativePath = try relativePath(for: url)
                guard let first = relativePath.split(separator: "/", omittingEmptySubsequences: false).first,
                      Lane2ManagedArtifactInventory.managedRootNames.contains(String(first)) else {
                    throw Lane2ManagedArtifactCensusFailure.candidateEscapedManagedRoots(relativePath)
                }
                if let afterRelativePath, relativePath <= afterRelativePath { continue }
                let candidate = Lane2ManagedArtifactCensusCandidate(
                    relativePath: relativePath,
                    modificationMicros: Self.modificationMicros(
                        values.contentModificationDate ?? .distantPast
                    ),
                    byteCount: Int64(max(values.fileSize ?? 0, 0))
                )
                insertBounded(candidate, into: &selected, capacity: limit + 1)
            }
            if enumerationFailed {
                throw Lane2ManagedArtifactCensusFailure.enumerationFailed(rootName)
            }
        }

        return ScanResult(
            selected: Array(selected.prefix(limit)),
            scannedRegularFiles: scannedRegularFiles,
            hasMore: selected.count > limit
        )
    }

    private func relativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard standardized.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactCensusFailure.candidateEscapedManagedRoots(url.path)
        }
        return try Self.normalize(String(standardized.path.dropFirst(prefix.count)))
    }

    private func loadState() throws -> Lane2ManagedArtifactCensusState? {
        guard fileManager.fileExists(atPath: stateURL.path) else { return nil }
        do {
            let values = try stateURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw Lane2ManagedArtifactCensusFailure.corruptState
            }
            let state = try JSONDecoder().decode(
                Lane2ManagedArtifactCensusState.self,
                from: Data(contentsOf: stateURL)
            )
            guard state.schemaVersion == Lane2ManagedArtifactCensusState.schemaVersion,
                  state.generation >= 1,
                  state.entryCount >= 0 else {
                throw Lane2ManagedArtifactCensusFailure.corruptState
            }
            if let after = state.afterRelativePath {
                guard try Self.normalize(after) == after else {
                    throw Lane2ManagedArtifactCensusFailure.corruptState
                }
            }
            return state
        } catch let failure as Lane2ManagedArtifactCensusFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactCensusFailure.corruptState
        }
    }

    private func persistState(_ state: Lane2ManagedArtifactCensusState) throws {
        try fileManager.createDirectory(at: censusDirectoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: [.atomic])
    }

    private func removeStateIfPresent() throws {
        guard fileManager.fileExists(atPath: stateURL.path) else { return }
        try fileManager.removeItem(at: stateURL)
    }

    private var censusDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Census", isDirectory: true)
    }

    private var stateURL: URL {
        censusDirectoryURL.appendingPathComponent("state.json", isDirectory: false)
    }

    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let fnvPrime: UInt64 = 1_099_511_628_211

    private static func initialState() -> Lane2ManagedArtifactCensusState {
        Lane2ManagedArtifactCensusState(
            schemaVersion: Lane2ManagedArtifactCensusState.schemaVersion,
            generation: 1,
            afterRelativePath: nil,
            rollingHash: offsetBasis,
            entryCount: 0,
            previousCompletedHash: nil,
            previousCompletedCount: nil
        )
    }

    private static func mix(
        _ hash: UInt64,
        candidate: Lane2ManagedArtifactCensusCandidate
    ) -> UInt64 {
        var value = hash
        let descriptor = "\(candidate.relativePath)\u{1f}\(candidate.modificationMicros)\u{1f}\(candidate.byteCount)\u{1e}"
        for byte in descriptor.utf8 {
            value ^= UInt64(byte)
            value &*= fnvPrime
        }
        return value
    }

    private static func modificationMicros(_ date: Date) -> Int64 {
        let seconds = date.timeIntervalSince1970
        if !seconds.isFinite { return Int64.min }
        let scaled = seconds * 1_000_000
        if scaled >= Double(Int64.max) { return Int64.max }
        if scaled <= Double(Int64.min) { return Int64.min }
        return Int64(scaled.rounded())
    }

    private static func normalize(_ relativePath: String) throws -> String {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactCensusFailure.candidateEscapedManagedRoots(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ManagedArtifactCensusFailure.candidateEscapedManagedRoots(relativePath)
        }
        return parts.joined(separator: "/")
    }
}

private func insertBounded(
    _ candidate: Lane2ManagedArtifactCensusCandidate,
    into buffer: inout [Lane2ManagedArtifactCensusCandidate],
    capacity: Int
) {
    guard capacity > 0 else { return }
    var low = 0
    var high = buffer.count
    while low < high {
        let mid = low + (high - low) / 2
        if buffer[mid].relativePath >= candidate.relativePath {
            high = mid
        } else {
            low = mid + 1
        }
    }
    buffer.insert(candidate, at: low)
    if buffer.count > capacity { buffer.removeLast() }
}
