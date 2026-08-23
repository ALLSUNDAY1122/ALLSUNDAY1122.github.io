import Foundation

public enum AnalysisBenchmarkSourceKind: String, Codable, Sendable {
    case realAudio = "REAL_AUDIO"
    case syntheticTest = "SYNTHETIC_TEST"
}

public enum AnalysisBenchmarkPermittedUse: String, Codable, Sendable, Hashable {
    case analysisBenchmark = "ANALYSIS_BENCHMARK"
    case internalQualityReview = "INTERNAL_QUALITY_REVIEW"
    case differentialReference = "DIFFERENTIAL_REFERENCE"
}

public struct AnalysisRightsEvidence: Codable, Equatable, Sendable {
    public let grantID: String
    public let rightsClass: AnalysisRightsClass
    public let permittedUses: Set<AnalysisBenchmarkPermittedUse>
    public let expiresAt: Date?
    public let sourceSHA256: String
    public let notes: String?

    public init(
        grantID: String,
        rightsClass: AnalysisRightsClass,
        permittedUses: Set<AnalysisBenchmarkPermittedUse>,
        expiresAt: Date? = nil,
        sourceSHA256: String,
        notes: String? = nil
    ) {
        self.grantID = grantID
        self.rightsClass = rightsClass
        self.permittedUses = permittedUses
        self.expiresAt = expiresAt
        self.sourceSHA256 = sourceSHA256.lowercased()
        self.notes = notes
    }
}

public struct AnalysisReferenceAnnotation: Codable, Equatable, Sendable {
    public let bpm: Double?
    public let beatTimesSeconds: [Double]
    public let key: MusicalKey?
    public let chords: [ChordEvent]
    public let sections: [SongSection]

    public init(
        bpm: Double? = nil,
        beatTimesSeconds: [Double] = [],
        key: MusicalKey? = nil,
        chords: [ChordEvent] = [],
        sections: [SongSection] = []
    ) {
        self.bpm = bpm
        self.beatTimesSeconds = beatTimesSeconds.sorted()
        self.key = key
        self.chords = chords.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
        self.sections = sections.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
    }

    public var coveredDomains: Set<String> {
        var domains = Set<String>()
        if bpm != nil { domains.insert("tempo") }
        if !beatTimesSeconds.isEmpty { domains.insert("beat") }
        if key != nil { domains.insert("key") }
        if !chords.isEmpty { domains.insert("chord") }
        if !sections.isEmpty { domains.insert("structure") }
        return domains
    }
}

public struct AnalysisRealAudioBenchmarkCase: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let projectID: UUID
    public let assetID: UUID
    public let relativePath: String
    public let genre: String
    public let sourceKind: AnalysisBenchmarkSourceKind
    public let expectedDurationSeconds: Double
    public let rights: AnalysisRightsEvidence
    public let reference: AnalysisReferenceAnnotation

    public init(
        fixtureID: String,
        projectID: UUID,
        assetID: UUID,
        relativePath: String,
        genre: String,
        sourceKind: AnalysisBenchmarkSourceKind,
        expectedDurationSeconds: Double,
        rights: AnalysisRightsEvidence,
        reference: AnalysisReferenceAnnotation
    ) {
        self.fixtureID = fixtureID
        self.projectID = projectID
        self.assetID = assetID
        self.relativePath = relativePath
        self.genre = genre
        self.sourceKind = sourceKind
        self.expectedDurationSeconds = expectedDurationSeconds
        self.rights = rights
        self.reference = reference
    }
}

public struct AnalysisRealAudioBenchmarkManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let manifestID: String
    public let createdAt: Date
    public let cases: [AnalysisRealAudioBenchmarkCase]

    public init(
        schemaVersion: Int = 1,
        manifestID: String,
        createdAt: Date,
        cases: [AnalysisRealAudioBenchmarkCase]
    ) {
        self.schemaVersion = schemaVersion
        self.manifestID = manifestID
        self.createdAt = createdAt
        self.cases = cases
    }
}

public enum AnalysisBenchmarkValidationCode: String, Codable, Sendable {
    case unsupportedSchema
    case emptyManifestID
    case emptyManifest
    case duplicateFixtureID
    case emptyFixtureID
    case emptyGenre
    case unsafeRelativePath
    case invalidDuration
    case emptyRightsGrantID
    case benchmarkUseNotPermitted
    case expiredRightsGrant
    case invalidSourceSHA256
    case noReferenceDomain
    case invalidReferenceBPM
    case beatOutsideDuration
    case beatOrderInvalid
    case chordOutsideDuration
    case chordOverlap
    case sectionOutsideDuration
    case sectionOverlapOrGap
    case sectionDoesNotCoverTrack
}

public struct AnalysisBenchmarkValidationIssue: Codable, Equatable, Sendable {
    public let fixtureID: String?
    public let code: AnalysisBenchmarkValidationCode
    public let detail: String

    public init(fixtureID: String?, code: AnalysisBenchmarkValidationCode, detail: String) {
        self.fixtureID = fixtureID
        self.code = code
        self.detail = detail
    }
}

public enum AnalysisRealAudioManifestValidator {
    public static func validate(
        _ manifest: AnalysisRealAudioBenchmarkManifest,
        at runDate: Date = Date()
    ) -> [AnalysisBenchmarkValidationIssue] {
        var issues: [AnalysisBenchmarkValidationIssue] = []
        if manifest.schemaVersion != 1 {
            issues.append(.init(fixtureID: nil, code: .unsupportedSchema, detail: "schema_version must equal 1"))
        }
        if manifest.manifestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(fixtureID: nil, code: .emptyManifestID, detail: "manifest_id is required"))
        }
        if manifest.cases.isEmpty {
            issues.append(.init(fixtureID: nil, code: .emptyManifest, detail: "at least one benchmark case is required"))
        }

        var seenFixtureIDs = Set<String>()
        for item in manifest.cases {
            let id = item.fixtureID
            if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(fixtureID: nil, code: .emptyFixtureID, detail: "fixture_id is required"))
            } else if !seenFixtureIDs.insert(id).inserted {
                issues.append(.init(fixtureID: id, code: .duplicateFixtureID, detail: "fixture_id must be unique"))
            }
            if item.genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(fixtureID: id, code: .emptyGenre, detail: "genre is required for stratified reporting"))
            }
            if !isSafeRelativePath(item.relativePath) {
                issues.append(.init(fixtureID: id, code: .unsafeRelativePath, detail: "relative_path must be app-owned, relative, and traversal-free"))
            }
            if !item.expectedDurationSeconds.isFinite || item.expectedDurationSeconds <= 0 {
                issues.append(.init(fixtureID: id, code: .invalidDuration, detail: "expected_duration_seconds must be finite and > 0"))
            }

            issues.append(contentsOf: validateRights(item, at: runDate))
            issues.append(contentsOf: validateReference(item))
        }
        return issues
    }

    public static func isParityEligible(
        _ item: AnalysisRealAudioBenchmarkCase,
        at runDate: Date = Date()
    ) -> Bool {
        guard item.sourceKind == .realAudio else { return false }
        return validate(
            AnalysisRealAudioBenchmarkManifest(
                manifestID: "single-case-validation",
                createdAt: runDate,
                cases: [item]
            ),
            at: runDate
        ).isEmpty
    }

    private static func validateRights(
        _ item: AnalysisRealAudioBenchmarkCase,
        at runDate: Date
    ) -> [AnalysisBenchmarkValidationIssue] {
        var issues: [AnalysisBenchmarkValidationIssue] = []
        if item.rights.grantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(fixtureID: item.fixtureID, code: .emptyRightsGrantID, detail: "rights grant identifier is required"))
        }
        if !item.rights.permittedUses.contains(.analysisBenchmark) {
            issues.append(.init(fixtureID: item.fixtureID, code: .benchmarkUseNotPermitted, detail: "rights grant must explicitly permit ANALYSIS_BENCHMARK"))
        }
        if let expiresAt = item.rights.expiresAt, expiresAt <= runDate {
            issues.append(.init(fixtureID: item.fixtureID, code: .expiredRightsGrant, detail: "rights grant is expired at benchmark run time"))
        }
        if !isSHA256(item.rights.sourceSHA256) {
            issues.append(.init(fixtureID: item.fixtureID, code: .invalidSourceSHA256, detail: "source_sha256 must be exactly 64 hexadecimal characters"))
        }
        return issues
    }

    private static func validateReference(
        _ item: AnalysisRealAudioBenchmarkCase
    ) -> [AnalysisBenchmarkValidationIssue] {
        var issues: [AnalysisBenchmarkValidationIssue] = []
        let reference = item.reference
        let duration = item.expectedDurationSeconds
        if reference.coveredDomains.isEmpty {
            issues.append(.init(fixtureID: item.fixtureID, code: .noReferenceDomain, detail: "at least one reference domain is required"))
        }
        if let bpm = reference.bpm, !bpm.isFinite || bpm <= 0 {
            issues.append(.init(fixtureID: item.fixtureID, code: .invalidReferenceBPM, detail: "reference BPM must be finite and > 0"))
        }
        if reference.beatTimesSeconds.contains(where: { !$0.isFinite || $0 < 0 || $0 > duration }) {
            issues.append(.init(fixtureID: item.fixtureID, code: .beatOutsideDuration, detail: "beat timestamps must stay inside source duration"))
        }
        if !strictlyIncreasing(reference.beatTimesSeconds) {
            issues.append(.init(fixtureID: item.fixtureID, code: .beatOrderInvalid, detail: "beat timestamps must be strictly increasing"))
        }

        var previousChordEnd = -Double.infinity
        for chord in reference.chords {
            if !finiteInterval(start: chord.startSeconds, end: chord.endSeconds, duration: duration) {
                issues.append(.init(fixtureID: item.fixtureID, code: .chordOutsideDuration, detail: "chord intervals must be finite, positive, and inside source duration"))
                break
            }
            if chord.startSeconds < previousChordEnd - 1e-9 {
                issues.append(.init(fixtureID: item.fixtureID, code: .chordOverlap, detail: "reference chord intervals must not overlap"))
                break
            }
            previousChordEnd = chord.endSeconds
        }

        if !reference.sections.isEmpty {
            var previousEnd = 0.0
            for (index, section) in reference.sections.enumerated() {
                if !finiteInterval(start: section.startSeconds, end: section.endSeconds, duration: duration) {
                    issues.append(.init(fixtureID: item.fixtureID, code: .sectionOutsideDuration, detail: "section intervals must be finite, positive, and inside source duration"))
                    break
                }
                if index == 0 {
                    if abs(section.startSeconds) > 0.001 {
                        issues.append(.init(fixtureID: item.fixtureID, code: .sectionDoesNotCoverTrack, detail: "section reference must start at source time 0"))
                    }
                } else if abs(section.startSeconds - previousEnd) > 0.001 {
                    issues.append(.init(fixtureID: item.fixtureID, code: .sectionOverlapOrGap, detail: "section reference must be ordered and gap-free"))
                    break
                }
                previousEnd = section.endSeconds
            }
            if let last = reference.sections.last, abs(last.endSeconds - duration) > 0.001 {
                issues.append(.init(fixtureID: item.fixtureID, code: .sectionDoesNotCoverTrack, detail: "section reference must end at source duration"))
            }
        }
        return issues
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.hasPrefix("\\") else { return false }
        let components = trimmed.replacingOccurrences(of: "\\", with: "/").split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains(where: { $0 == ".." || $0.isEmpty })
    }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value) || (65...70).contains(scalar.value)
        }
    }

    private static func strictlyIncreasing(_ values: [Double]) -> Bool {
        guard values.count > 1 else { return true }
        for index in 1..<values.count where values[index] <= values[index - 1] { return false }
        return true
    }

    private static func finiteInterval(start: Double, end: Double, duration: Double) -> Bool {
        start.isFinite && end.isFinite && start >= 0 && end > start && end <= duration + 1e-9
    }
}

public struct AnalysisBenchmarkLoadedSignal: Equatable, Sendable {
    public let signal: AnalysisSignal
    public let sourceSHA256: String

    public init(signal: AnalysisSignal, sourceSHA256: String) {
        self.signal = signal
        self.sourceSHA256 = sourceSHA256.lowercased()
    }
}

public protocol AnalysisBenchmarkSignalLoading: Sendable {
    func loadBenchmarkSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisBenchmarkLoadedSignal
}

public struct AnalysisBenchmarkDomainSummary: Codable, Equatable, Sendable {
    public let domain: String
    public let fixtureCount: Int
    public let parityEligibleFixtureCount: Int
    public let meanMetrics: [String: Double]
}

public struct AnalysisRealAudioBenchmarkReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let manifestID: String
    public let generatedAt: Date
    public let engine: String
    public let engineVersion: String
    public let parityEligible: Bool
    public let rows: [AnalysisBenchmarkRow]
    public let summaries: [AnalysisBenchmarkDomainSummary]
    public let validationIssues: [AnalysisBenchmarkValidationIssue]

    public init(
        schemaVersion: Int = 1,
        manifestID: String,
        generatedAt: Date,
        engine: String,
        engineVersion: String,
        parityEligible: Bool,
        rows: [AnalysisBenchmarkRow],
        summaries: [AnalysisBenchmarkDomainSummary],
        validationIssues: [AnalysisBenchmarkValidationIssue]
    ) {
        self.schemaVersion = schemaVersion
        self.manifestID = manifestID
        self.generatedAt = generatedAt
        self.engine = engine
        self.engineVersion = engineVersion
        self.parityEligible = parityEligible
        self.rows = rows
        self.summaries = summaries
        self.validationIssues = validationIssues
    }
}

public enum AnalysisRealAudioBenchmarkError: Error, Equatable, Sendable {
    case invalidManifest([AnalysisBenchmarkValidationIssue])
    case durationMismatch(fixtureID: String, expected: Double, actual: Double)
    case nonFiniteSignal(fixtureID: String)
    case sourceChecksumMismatch(fixtureID: String, expected: String, actual: String)
}

public enum AnalysisRealAudioBenchmarkRunner {
    public static func run(
        manifest: AnalysisRealAudioBenchmarkManifest,
        loader: any AnalysisBenchmarkSignalLoading,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        engine: String = "project-owned-dsp",
        engineVersion: String = "lane4-autonomous-v1",
        runDate: Date = Date()
    ) async throws -> AnalysisRealAudioBenchmarkReport {
        let validationIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: runDate)
        guard validationIssues.isEmpty else {
            throw AnalysisRealAudioBenchmarkError.invalidManifest(validationIssues)
        }

        var rows: [AnalysisBenchmarkRow] = []
        var allCasesParityEligible = true
        for item in manifest.cases {
            let asset = LocalAudioAsset(
                id: AssetID(rawValue: item.assetID),
                relativePath: item.relativePath,
                mediaKind: .audio,
                durationSeconds: item.expectedDurationSeconds
            )
            let loaded = try await loader.loadBenchmarkSignal(projectID: ProjectID(rawValue: item.projectID), asset: asset)
            guard loaded.sourceSHA256.caseInsensitiveCompare(item.rights.sourceSHA256) == .orderedSame else {
                throw AnalysisRealAudioBenchmarkError.sourceChecksumMismatch(
                    fixtureID: item.fixtureID,
                    expected: item.rights.sourceSHA256,
                    actual: loaded.sourceSHA256
                )
            }
            let signal = loaded.signal
            let tolerance = max(0.050, item.expectedDurationSeconds * 0.001)
            guard abs(signal.durationSeconds - item.expectedDurationSeconds) <= tolerance else {
                throw AnalysisRealAudioBenchmarkError.durationMismatch(
                    fixtureID: item.fixtureID,
                    expected: item.expectedDurationSeconds,
                    actual: signal.durationSeconds
                )
            }
            guard signal.monoSamples.allSatisfy({ $0.isFinite }) else {
                throw AnalysisRealAudioBenchmarkError.nonFiniteSignal(fixtureID: item.fixtureID)
            }

            let start = Date()
            let tempo = TempoBeatAnalyzer.analyze(signal: signal, configuration: configuration)
            let key = MusicalKeyAnalyzer.analyze(signal: signal, configuration: configuration)
            let chords = ChordTimelineAnalyzer.analyze(signal: signal, configuration: configuration)
            let sections = SongSectionAnalyzer.analyze(signal: signal, chords: chords, configuration: configuration)
            let wallSeconds = max(0, Date().timeIntervalSince(start))
            let snapshot = AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: sections)
            let parityEligible = AnalysisRealAudioManifestValidator.isParityEligible(item, at: runDate)
            allCasesParityEligible = allCasesParityEligible && parityEligible

            let fixture = AnalysisBenchmarkFixture(
                fixtureID: item.fixtureID,
                rightsClass: item.rights.rightsClass,
                genre: item.genre,
                syntheticOnly: item.sourceKind != .realAudio,
                signal: signal,
                reference: TempoBeatKeyReference(
                    bpm: item.reference.bpm,
                    beatTimesSeconds: item.reference.beatTimesSeconds,
                    key: item.reference.key,
                    chords: item.reference.chords
                )
            )
            rows.append(contentsOf: AnalysisBenchmarkRunner.evaluate(
                fixture: fixture,
                snapshot: snapshot,
                wallSeconds: wallSeconds,
                engine: engine,
                engineVersion: engineVersion
            ))
            if !item.reference.sections.isEmpty {
                rows.append(SectionBenchmarkEvaluator.evaluate(
                    fixture: fixture,
                    reference: item.reference.sections,
                    snapshot: snapshot,
                    wallSeconds: wallSeconds,
                    engine: engine,
                    engineVersion: engineVersion
                ))
            }
        }

        return AnalysisRealAudioBenchmarkReport(
            manifestID: manifest.manifestID,
            generatedAt: runDate,
            engine: engine,
            engineVersion: engineVersion,
            parityEligible: allCasesParityEligible && rows.allSatisfy(\.parityEligible),
            rows: rows,
            summaries: summarize(rows),
            validationIssues: []
        )
    }

    public static func summarize(_ rows: [AnalysisBenchmarkRow]) -> [AnalysisBenchmarkDomainSummary] {
        let grouped = Dictionary(grouping: rows, by: \.domain)
        return grouped.keys.sorted().map { domain in
            let domainRows = grouped[domain] ?? []
            var valuesByMetric: [String: [Double]] = [:]
            for row in domainRows {
                for (metric, value) in row.metrics where value.isFinite {
                    valuesByMetric[metric, default: []].append(value)
                }
            }
            let means = valuesByMetric.mapValues { values in
                values.reduce(0, +) / Double(values.count)
            }
            return AnalysisBenchmarkDomainSummary(
                domain: domain,
                fixtureCount: domainRows.count,
                parityEligibleFixtureCount: domainRows.filter(\.parityEligible).count,
                meanMetrics: means
            )
        }
    }
}
