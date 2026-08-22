import Foundation

public enum HostModuleSlot: String, CaseIterable, Equatable, Sendable {
    case io
    case separation
    case playback
    case analysis
    case library
    case export
    case dsp
}

public enum HostCompositionError: Error, Equatable, Sendable {
    case missingRequiredModules([HostModuleSlot])
}

/// Lane-4 owns only the host/composition boundary. Implementations for IO, Library,
/// Playback, DSP and Separation are intentionally not copied into this lane.
/// HQ injects concrete lane implementations during Late Integration.
public struct HostModuleSlots: Sendable {
    public let importer: (any AudioImporting)?
    public let separator: (any SourceSeparationProviding)?
    public let playback: (any PlaybackPreparing)?
    public let analysis: (any MusicAnalyzing)?
    public let persistence: (any ProjectPersisting)?
    public let exporter: (any AudioExporting)?
    public let practiceDSP: (any PracticeDSPConfiguring)?

    public init(
        importer: (any AudioImporting)? = nil,
        separator: (any SourceSeparationProviding)? = nil,
        playback: (any PlaybackPreparing)? = nil,
        analysis: (any MusicAnalyzing)? = nil,
        persistence: (any ProjectPersisting)? = nil,
        exporter: (any AudioExporting)? = nil,
        practiceDSP: (any PracticeDSPConfiguring)? = nil
    ) {
        self.importer = importer
        self.separator = separator
        self.playback = playback
        self.analysis = analysis
        self.persistence = persistence
        self.exporter = exporter
        self.practiceDSP = practiceDSP
    }

    public static let empty = HostModuleSlots()

    /// Modules required by the frozen VerticalSliceCoordinator constructor.
    public var missingCoordinatorModules: [HostModuleSlot] {
        var missing: [HostModuleSlot] = []
        if importer == nil { missing.append(.io) }
        if separator == nil { missing.append(.separation) }
        if playback == nil { missing.append(.playback) }
        if analysis == nil { missing.append(.analysis) }
        if persistence == nil { missing.append(.library) }
        if exporter == nil { missing.append(.export) }
        return missing
    }

    /// Full late-integration surface, including DSP which is configured outside
    /// the current VerticalSliceCoordinator contract.
    public var missingLateIntegrationModules: [HostModuleSlot] {
        var missing = missingCoordinatorModules
        if practiceDSP == nil { missing.append(.dsp) }
        return missing
    }

    public func makeCoordinator() throws -> VerticalSliceCoordinator {
        let missing = missingCoordinatorModules
        guard missing.isEmpty,
              let importer,
              let separator,
              let playback,
              let analysis,
              let persistence,
              let exporter else {
            throw HostCompositionError.missingRequiredModules(missing)
        }

        return VerticalSliceCoordinator(
            importer: importer,
            separator: separator,
            playback: playback,
            analysisEngine: analysis,
            persistence: persistence,
            exporter: exporter
        )
    }
}
